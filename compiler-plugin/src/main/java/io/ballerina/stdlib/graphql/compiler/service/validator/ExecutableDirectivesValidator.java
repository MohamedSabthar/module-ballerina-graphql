package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.ResourceMethodSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.BasicLiteralNode;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.ExpressionNode;
import io.ballerina.compiler.syntax.tree.ListConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingFieldNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.SpecificFieldNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic;
import io.ballerina.tools.diagnostics.Location;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static io.ballerina.stdlib.graphql.commons.utils.Utils.isGraphqlModuleSymbol;
import static io.ballerina.stdlib.graphql.compiler.Utils.getDirectiveConfigAnnotationNode;
import static io.ballerina.stdlib.graphql.compiler.Utils.getValueFromStringLiteral;
import static io.ballerina.stdlib.graphql.compiler.Utils.hasDirectiveTypeInclusion;
import static io.ballerina.stdlib.graphql.compiler.Utils.isRemoteMethod;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_CONFIG_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_LOCATION_NOT_SUPPORTED;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_TYPE_INCLUSION_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.INVALID_DIRECTIVE_NAME;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.INVALID_INIT_METHOD_RETURN_TYPE_FOUND_IN_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.INVALID_REMOTE_METHOD_INSIDE_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.INVALID_RESOURCE_METHOD_INSIDE_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.NO_ON_FIELD_FOUND_FOR_DIRECTIVE_REMOTE_METHOD;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.NO_REMOTE_METHOD_FOUND_FOR_ON_FIELD_VALUE;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.ON_FIELD_MUST_CONTAIN_LEAST_ONE_VALUE_IN_DIRECTIVE_CONFIG;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.PASSING_NON_STRING_VALUE_FOR_NAME_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.PASSING_REFERENCE_FOR_ON_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.PASSING_SHORT_HAND_NOTATION_FOR_DIRECTIVE_CONFIG_NOT_SUPPORTED;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.PASSING_STRING_TEMPLATE_FOR_NAME_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.PASSING_STRING_TEMPLATE_FOR_ON_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.REMOTE_METHOD_WITH_INVALID_PARAMETERS_FOUND_IN_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.REMOTE_METHOD_WITH_INVALID_RETURN_TYPE_FOUND_IN_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.getLocation;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.updateContext;

/**
 * Validate Executable directives in Ballerina GraphQL services.
 */
public class ExecutableDirectivesValidator {

    public static final String ANONYMOUS_CLASS_NAME = "$anonymous";

    // Directive optional method names
    private static final String APPLY_ON_QUERY = "applyOnQuery";
    private static final String APPLY_ON_MUTATION = "applyOnMutation";
    private static final String APPLY_ON_SUBSCRIPTION = "applyOnSubscription";
    private static final String APPLY_ON_FIELD = "applyOnField";

    // Directive remote method parameters
    private static final String CONTEXT = "Context";
    private static final String FIELD = "Field";

    // DirectiveConfig annotation field names
    private static final String NAME_FIELD_NAME = "name";
    private static final String ON_FIELD_NAME = "'on";

    // Possible 'on field values in DirectiveConfig annotation
    private static final String QUERY_ON_FIELD_VALUE = "QUERY";
    private static final String MUTATION_ON_FIELD_VALUE = "MUTATION";
    private static final String SUBSCRIPTION_ON_FIELD_VALUE = "SUBSCRIPTION";
    private static final String FIELD_ON_FIELD_VALUE = "FIELD";

    private static final String GRAPHQL_IDENTIFIER_REGEX = "[_A-Za-z]\\w*";
    private static final String INIT_METHOD_NAME = "init";

    private final SyntaxNodeAnalysisContext context;
    private final Map<String, ClassDefinitionNode> executableDirectives;
    private final List<MethodSymbol> initMethodSymbols = new ArrayList<>();

    private Set<String> onFieldValues;
    private Set<String> remoteMethodNames;
    private boolean errorOccurred = false;

    public ExecutableDirectivesValidator(SyntaxNodeAnalysisContext context,
                                         Map<String, ClassDefinitionNode> executableDirectives) {
        this.context = context;
        this.executableDirectives = executableDirectives;
    }

    public void validate() {
        for (Map.Entry<String, ClassDefinitionNode> entry : this.executableDirectives.entrySet()) {
            String directiveName = entry.getKey();
            ClassDefinitionNode classDefinitionNode = entry.getValue();
            validateDirective(directiveName, classDefinitionNode);
        }
    }

    private void validateDirective(String directiveName, ClassDefinitionNode classDefinitionNode) {
        this.onFieldValues = new HashSet<>();
        this.remoteMethodNames = new HashSet<>();
        Optional<Symbol> symbol = this.context.semanticModel().symbol(classDefinitionNode);
        if (symbol.isEmpty()) {
            return;
        }
        ClassSymbol classSymbol = (ClassSymbol) symbol.get();
        Location location = classSymbol.getLocation().orElse(classDefinitionNode.location());
        validateDirectiveTypeInclusion(classSymbol, location);
        validateDirectiveConfig(classDefinitionNode, classSymbol, directiveName);

        for (Node member : classDefinitionNode.members()) {
            validateDirectiveServiceMember(member, location);
        }
        validateOnFieldToRemoteMethodMapping(location, classSymbol.getName().orElse(directiveName));
    }

    private void validateDirectiveTypeInclusion(ClassSymbol classSymbol, Location location) {
        String className = classSymbol.getName().orElse(ANONYMOUS_CLASS_NAME);
        if (hasDirectiveTypeInclusion(classSymbol)) {
            return;
        }
        addDiagnosticError(DIRECTIVE_TYPE_INCLUSION_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS, location, className);
    }

    private void validateDirectiveConfig(ClassDefinitionNode classDefinitionNode, ClassSymbol classSymbol,
                                         String directiveName) {
        String className = classSymbol.getName().orElse(ANONYMOUS_CLASS_NAME);
        Optional<AnnotationNode> directiveConfigAnnotationNode = getDirectiveConfigAnnotationNode(
                this.context.semanticModel(), classDefinitionNode);
        if (directiveConfigAnnotationNode.isEmpty()) {
            addDiagnosticError(DIRECTIVE_CONFIG_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS, classDefinitionNode.location(),
                               className);
            return;
        }
        // noinspection OptionalGetWithoutIsPresent
        MappingConstructorExpressionNode expressionNode = directiveConfigAnnotationNode.get().annotValue().get();
        Location onValueLocation;
        for (MappingFieldNode field : expressionNode.fields()) {
            if (field.kind() != SyntaxKind.SPECIFIC_FIELD) {
                continue;
            }
            SpecificFieldNode specificFieldNode = (SpecificFieldNode) field;
            String fieldName = specificFieldNode.fieldName().toString().trim();
            if (fieldName.equals(NAME_FIELD_NAME)) {
                if (specificFieldNode.valueExpr().isEmpty()) {
                    addDiagnosticWarning(PASSING_SHORT_HAND_NOTATION_FOR_DIRECTIVE_CONFIG_NOT_SUPPORTED, field.location());
                    continue;
                }
                if (specificFieldNode.valueExpr().get().kind() != SyntaxKind.STRING_LITERAL) {
                    addDiagnosticWarning(PASSING_NON_STRING_VALUE_FOR_NAME_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED,
                                         field.location());
                    continue;
                }
                ExpressionNode stringLiteral = specificFieldNode.valueExpr().get();
                if (!(stringLiteral instanceof BasicLiteralNode)) {
                    addDiagnosticWarning(PASSING_STRING_TEMPLATE_FOR_NAME_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED,
                                         field.location());
                    continue;
                }
                validateDirectiveName(directiveName, field.location());
            } else if (fieldName.equals(ON_FIELD_NAME)) {
                if (specificFieldNode.valueExpr().isEmpty()) {
                    continue;
                }
                onValueLocation = specificFieldNode.valueExpr().get().location();
                SyntaxKind syntaxKind = specificFieldNode.valueExpr().get().kind();
                if (syntaxKind != SyntaxKind.QUALIFIED_NAME_REFERENCE && syntaxKind != SyntaxKind.LIST_CONSTRUCTOR
                        && syntaxKind != SyntaxKind.STRING_LITERAL) {
                    addDiagnosticWarning(PASSING_REFERENCE_FOR_ON_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED,
                                         field.location());
                    continue;
                }
                readOnFieldValues(specificFieldNode.valueExpr().get());
                validateOnFieldValues(onValueLocation == null ? expressionNode.location() : onValueLocation);
            }
        }
    }

    private void validateDirectiveName(String directiveName, Location location) {
        if (!directiveName.matches(GRAPHQL_IDENTIFIER_REGEX)) {
            addDiagnosticError(INVALID_DIRECTIVE_NAME, location, directiveName);
        }
    }

    private void readOnFieldValues(ExpressionNode expressionNode) {
        if (expressionNode.kind() == SyntaxKind.QUALIFIED_NAME_REFERENCE) {
            this.onFieldValues.add(expressionNode.toString().split(SyntaxKind.COLON_TOKEN.stringValue())[1].trim());
        } else if (expressionNode.kind() == SyntaxKind.LIST_CONSTRUCTOR) {
            ListConstructorExpressionNode listConstructorExpressionNode
                    = (ListConstructorExpressionNode) expressionNode;
            for (Node member : listConstructorExpressionNode.expressions()) {
                if (member.kind() == SyntaxKind.STRING_LITERAL) {
                    if (!(member instanceof BasicLiteralNode)) {
                        addDiagnosticWarning(PASSING_STRING_TEMPLATE_FOR_ON_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED,
                                             member.location());
                        continue;
                    }
                    String fieldValue = getValueFromStringLiteral((BasicLiteralNode) member);
                    this.onFieldValues.add(fieldValue);
                } else if (member.kind() == SyntaxKind.QUALIFIED_NAME_REFERENCE) {
                    this.onFieldValues.add(member.toString().split(SyntaxKind.COLON_TOKEN.stringValue())[1].trim());
                }
            }
        }
    }

    private void validateOnFieldValues(Location valueLocation) {
        if (this.onFieldValues.size() < 1) {
            addDiagnosticError(ON_FIELD_MUST_CONTAIN_LEAST_ONE_VALUE_IN_DIRECTIVE_CONFIG, valueLocation);
        }
        for (String onFieldValue : this.onFieldValues) {
            if (!onFieldValue.equals(QUERY_ON_FIELD_VALUE) && !onFieldValue.equals(MUTATION_ON_FIELD_VALUE)
                    && !onFieldValue.equals(SUBSCRIPTION_ON_FIELD_VALUE) && !onFieldValue.equals(
                    FIELD_ON_FIELD_VALUE)) {
                addDiagnosticWarning(DIRECTIVE_LOCATION_NOT_SUPPORTED, valueLocation, onFieldValue);
            }
        }
    }

    private void validateDirectiveServiceMember(Node node, Location location) {
        if (this.context.semanticModel().symbol(node).isEmpty()) {
            return;
        }
        Symbol symbol = this.context.semanticModel().symbol(node).get();
        if (symbol.kind() == SymbolKind.METHOD) {
            MethodSymbol methodSymbol = (MethodSymbol) symbol;
            if (isRemoteMethod(methodSymbol)) {
                validateRemoteMethod(methodSymbol, location);
            } else if (isInitMethod(methodSymbol)) {
                // TODO: validate init method
                validateInitMethod(methodSymbol, location);
                this.initMethodSymbols.add(methodSymbol);
            }
        } else if (symbol.kind() == SymbolKind.RESOURCE_METHOD) {
            ResourceMethodSymbol resourceMethodSymbol = (ResourceMethodSymbol) symbol;
            String resourceMethodSignature = resourceMethodSymbol.signature();
            addDiagnosticError(INVALID_RESOURCE_METHOD_INSIDE_DIRECTIVE, getLocation(resourceMethodSymbol, location),
                               resourceMethodSignature);
        }
    }

    private boolean isInitMethod(MethodSymbol methodSymbol) {
        if (methodSymbol.getName().isEmpty()) {
            return false;
        }
        return methodSymbol.getName().get().equals(INIT_METHOD_NAME);
    }

    private void validateInitMethod(MethodSymbol methodSymbol, Location location) {
        Optional<TypeSymbol> returnTypeDesc = methodSymbol.typeDescriptor().returnTypeDescriptor();
        if (returnTypeDesc.isPresent() && returnTypeDesc.get().typeKind() != TypeDescKind.NIL) {
            addDiagnosticError(INVALID_INIT_METHOD_RETURN_TYPE_FOUND_IN_DIRECTIVE,
                               getLocation(returnTypeDesc.get(), getLocation(methodSymbol, location)),
                               returnTypeDesc.get().signature());
        }
    }

    private void validateRemoteMethod(MethodSymbol methodSymbol, Location location) {
        // noinspection OptionalGetWithoutIsPresent
        String methodName = methodSymbol.getName().get();
        if (!isAllowedRemoteMethodName(methodName)) {
            addDiagnosticError(INVALID_REMOTE_METHOD_INSIDE_DIRECTIVE, getLocation(methodSymbol, location),
                               methodSymbol.getName().orElse(methodSymbol.signature()));
            return;
        }
        validateRemoteMethodSignature(methodSymbol, location);
        // Check if the on field value is present in the directive config for given remote method
        if (!this.onFieldValues.contains(getOnFieldValueMapping(methodName))) {
            addDiagnosticError(NO_ON_FIELD_FOUND_FOR_DIRECTIVE_REMOTE_METHOD, getLocation(methodSymbol, location),
                               methodSymbol.getName().orElse(methodSymbol.signature()),
                               getOnFieldValueMapping(methodName));
        }
    }

    private void validateRemoteMethodSignature(MethodSymbol methodSymbol, Location location) {
        // noinspection OptionalGetWithoutIsPresent
        String methodName = methodSymbol.getName().get();
        validateRemoteMethodParameters(methodSymbol, location);
        validateRemoteMethodReturnType(methodSymbol, location);
        this.remoteMethodNames.add(methodName);
    }

    private void validateRemoteMethodReturnType(MethodSymbol methodSymbol, Location location) {
        // noinspection OptionalGetWithoutIsPresent
        String methodName = methodSymbol.getName().get();
        Optional<TypeSymbol> returnTypedesc = methodSymbol.typeDescriptor().returnTypeDescriptor();
        location = getLocation(methodSymbol, location);
        if (returnTypedesc.isEmpty()) {
            addDiagnosticError(REMOTE_METHOD_WITH_INVALID_RETURN_TYPE_FOUND_IN_DIRECTIVE, location, methodName);
            return;
        }

        TypeDescKind returnTypeKind = returnTypedesc.get().typeKind();
        if (returnTypeKind != TypeDescKind.ANYDATA && returnTypeKind != TypeDescKind.ERROR
                && !isValidUnionReturnType(returnTypedesc.get())) {
            addDiagnosticError(REMOTE_METHOD_WITH_INVALID_RETURN_TYPE_FOUND_IN_DIRECTIVE, location, methodName);
        }
    }

    private boolean isValidUnionReturnType(TypeSymbol returnTypeSymbol) {
        if (returnTypeSymbol.typeKind() != TypeDescKind.UNION) {
            return false;
        }
        for (TypeSymbol symbol : ((UnionTypeSymbol) returnTypeSymbol).memberTypeDescriptors()) {
            if (symbol.typeKind() != TypeDescKind.ANYDATA && symbol.typeKind() != TypeDescKind.ERROR) {
                return false;
            }
        }
        return true;
    }

    private void validateRemoteMethodParameters(MethodSymbol methodSymbol, Location location) {
        // noinspection OptionalGetWithoutIsPresent
        String methodName = methodSymbol.getName().get();
        Optional<List<ParameterSymbol>> params = methodSymbol.typeDescriptor().params();
        if (params.isEmpty() || params.get().size() != 2 || !isExpectedParameterType(params.get().get(0), CONTEXT)
                || !isExpectedParameterType(params.get().get(1), FIELD)) {
            addDiagnosticError(REMOTE_METHOD_WITH_INVALID_PARAMETERS_FOUND_IN_DIRECTIVE,
                               getLocation(methodSymbol, location), methodName);
        }
    }

    private boolean isExpectedParameterType(ParameterSymbol parameterSymbol, String expectedTypeName) {
        if (parameterSymbol.typeDescriptor().getName().isEmpty()) {
            return false;
        }
        TypeSymbol typeDescriptor = parameterSymbol.typeDescriptor();
        if (typeDescriptor.getName().isEmpty()) {
            return false;
        }
        return typeDescriptor.getName().get().equals(expectedTypeName) && isGraphqlModuleSymbol(typeDescriptor);
    }

    private boolean isAllowedRemoteMethodName(String methodName) {
        switch (methodName) {
            case APPLY_ON_QUERY:
            case APPLY_ON_MUTATION:
            case APPLY_ON_SUBSCRIPTION:
            case APPLY_ON_FIELD:
                return true;
        }
        return false;
    }

    private void validateOnFieldToRemoteMethodMapping(Location location, String directiveClassName) {
        for (String onFieldValue : this.onFieldValues) {
            if (!this.remoteMethodNames.contains(getRemoteMethodMapping(onFieldValue))) {
                addDiagnosticError(NO_REMOTE_METHOD_FOUND_FOR_ON_FIELD_VALUE, location, directiveClassName,
                                   onFieldValue);
            }
        }
    }

    private String getRemoteMethodMapping(String fieldName) {
        switch (fieldName) {
            case QUERY_ON_FIELD_VALUE:
                return APPLY_ON_QUERY;
            case MUTATION_ON_FIELD_VALUE:
                return APPLY_ON_MUTATION;
            case SUBSCRIPTION_ON_FIELD_VALUE:
                return APPLY_ON_SUBSCRIPTION;
            case FIELD_ON_FIELD_VALUE:
                return APPLY_ON_FIELD;
            default:
                return null;

        }
    }

    private String getOnFieldValueMapping(String remoteMethodName) {
        switch (remoteMethodName) {
            case APPLY_ON_QUERY:
                return QUERY_ON_FIELD_VALUE;
            case APPLY_ON_MUTATION:
                return MUTATION_ON_FIELD_VALUE;
            case APPLY_ON_SUBSCRIPTION:
                return SUBSCRIPTION_ON_FIELD_VALUE;
            case APPLY_ON_FIELD:
                return FIELD_ON_FIELD_VALUE;
            default:
                return null;

        }
    }

    private void addDiagnosticError(CompilationDiagnostic compilationDiagnostic, Location location, Object... args) {
        updateContext(this.context, compilationDiagnostic, location, args);
        this.errorOccurred = true;
    }

    private void addDiagnosticWarning(CompilationDiagnostic compilationDiagnostic, Location location, Object... args) {
        updateContext(this.context, compilationDiagnostic, location, args);
    }

    public boolean isErrorOccurred() {
        return this.errorOccurred;
    }

    public List<MethodSymbol> getInitMethodSymbols() {
        return this.initMethodSymbols;
    }
}
