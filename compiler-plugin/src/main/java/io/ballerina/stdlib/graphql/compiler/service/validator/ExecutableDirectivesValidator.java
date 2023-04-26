package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.FunctionTypeSymbol;
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

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static io.ballerina.stdlib.graphql.commons.utils.Utils.isGraphqlModuleSymbol;
import static io.ballerina.stdlib.graphql.compiler.Utils.getDirectiveConfigAnnotationNode;
import static io.ballerina.stdlib.graphql.compiler.Utils.getValueFromStringLiteral;
import static io.ballerina.stdlib.graphql.compiler.Utils.hasDirectiveTypeInclusion;
import static io.ballerina.stdlib.graphql.compiler.Utils.isInitMethod;
import static io.ballerina.stdlib.graphql.compiler.Utils.isRemoteMethod;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_CONFIG_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_LOCATION_NOT_SUPPORTED;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_NAME_ALREADY_IN_USE;
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
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.REMOTE_METHOD_WITH_INVALID_PARAMETERS_FOUND_IN_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.REMOTE_METHOD_WITH_INVALID_RETURN_TYPE_FOUND_IN_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.getLocation;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.updateContext;

/**
 * Validate Executable directives in Ballerina GraphQL services.
 */
public class ExecutableDirectivesValidator {

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

    private final SyntaxNodeAnalysisContext context;
    private final Map<String, ClassDefinitionNode> executableDirectives;
    private final Map<String, String> onFieldRemoteMethodMapping = new HashMap<>();
    private final Set<String> validatedDirectiveNames = new HashSet<>();
    private final Set<String> onFieldValues = new HashSet<>();
    private final Set<String> remoteMethodNames = new HashSet<>();
    private final InputTypeValidator inputTypeValidator;

    private boolean errorOccurred = false;

    public ExecutableDirectivesValidator(SyntaxNodeAnalysisContext context,
                                         Map<String, ClassDefinitionNode> executableDirectives,
                                         InputTypeValidator inputTypeValidator) {
        this.context = context;
        this.executableDirectives = executableDirectives;
        this.inputTypeValidator = inputTypeValidator;
        addOnFieldRemoteMethodMapping();
    }

    private void addOnFieldRemoteMethodMapping() {
        // on field value -> remote method name
        this.onFieldRemoteMethodMapping.put(QUERY_ON_FIELD_VALUE, APPLY_ON_QUERY);
        this.onFieldRemoteMethodMapping.put(MUTATION_ON_FIELD_VALUE, APPLY_ON_MUTATION);
        this.onFieldRemoteMethodMapping.put(SUBSCRIPTION_ON_FIELD_VALUE, APPLY_ON_SUBSCRIPTION);
        this.onFieldRemoteMethodMapping.put(FIELD_ON_FIELD_VALUE, APPLY_ON_FIELD);

        // remote method name -> on field value
        this.onFieldRemoteMethodMapping.put(APPLY_ON_QUERY, QUERY_ON_FIELD_VALUE);
        this.onFieldRemoteMethodMapping.put(APPLY_ON_MUTATION, MUTATION_ON_FIELD_VALUE);
        this.onFieldRemoteMethodMapping.put(APPLY_ON_SUBSCRIPTION, SUBSCRIPTION_ON_FIELD_VALUE);
        this.onFieldRemoteMethodMapping.put(APPLY_ON_FIELD, FIELD_ON_FIELD_VALUE);
    }

    public void validate() {
        for (Map.Entry<String, ClassDefinitionNode> entry : this.executableDirectives.entrySet()) {
            String directiveClassName = entry.getKey();
            ClassDefinitionNode classDefinitionNode = entry.getValue();
            validateDirective(directiveClassName, classDefinitionNode);
        }
    }

    private void validateDirective(String directiveClassName, ClassDefinitionNode classDefinitionNode) {
        this.onFieldValues.clear();
        this.remoteMethodNames.clear();

        // No need to check isPresent(), already validated in ExecutableDirectiveNodeVisitor
        // noinspection OptionalGetWithoutIsPresent
        ClassSymbol classSymbol = (ClassSymbol) this.context.semanticModel().symbol(classDefinitionNode).get();
        Location location = classSymbol.getLocation().orElse(classDefinitionNode.location());
        validateDirectiveTypeInclusion(classSymbol, directiveClassName, location);
        validateDirectiveConfig(classDefinitionNode, directiveClassName);

        for (Node member : classDefinitionNode.members()) {
            validateDirectiveServiceMember(member, location, directiveClassName);
        }
        validateOnFieldToRemoteMethodMapping(location, directiveClassName);
    }

    private void validateDirectiveTypeInclusion(ClassSymbol classSymbol, String className, Location location) {
        if (hasDirectiveTypeInclusion(classSymbol)) {
            return;
        }
        addDiagnosticError(DIRECTIVE_TYPE_INCLUSION_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS, location, className);
    }

    private void addDiagnosticError(CompilationDiagnostic compilationDiagnostic, Location location, Object... args) {
        updateContext(this.context, compilationDiagnostic, location, args);
        this.errorOccurred = true;
    }

    private void validateDirectiveConfig(ClassDefinitionNode classDefinitionNode, String directiveClassName) {
        Optional<AnnotationNode> configAnnotationNode = getDirectiveConfigAnnotationNode(this.context.semanticModel(),
                                                                                         classDefinitionNode);
        if (configAnnotationNode.isEmpty()) {
            addDiagnosticError(DIRECTIVE_CONFIG_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS, classDefinitionNode.location(),
                               directiveClassName);
            return;
        }
        Optional<MappingConstructorExpressionNode> annotationValue = configAnnotationNode.get().annotValue();
        if (annotationValue.isEmpty()) {
            return;
        }
        validateDirectiveConfigFields(directiveClassName, annotationValue.get());
    }

    private void validateDirectiveConfigFields(String directiveClassName,
                                               MappingConstructorExpressionNode expressionNode) {
        Location nameFieldLocation = expressionNode.location();
        String directiveName = directiveClassName;
        for (MappingFieldNode field : expressionNode.fields()) {
            if (field.kind() != SyntaxKind.SPECIFIC_FIELD) {
                continue;
            }
            SpecificFieldNode specificFieldNode = (SpecificFieldNode) field;
            String fieldName = specificFieldNode.fieldName().toString().trim();
            if (fieldName.equals(NAME_FIELD_NAME)) {
                nameFieldLocation = field.location();
                String overriddenDirectiveName = getNameFromDirectiveConfigNameField(specificFieldNode,
                                                                                     field.location());
                if (overriddenDirectiveName != null) {
                    directiveName = overriddenDirectiveName;
                }
                validateDirectiveName(directiveName, field.location());
            } else if (fieldName.equals(ON_FIELD_NAME)) {
                validateDirectiveConfigOnField(expressionNode, specificFieldNode, field.location());
            }
        }
        updateValidatedDirectiveNameSet(directiveName, nameFieldLocation);
    }

    private void updateValidatedDirectiveNameSet(String directiveName, Location location) {
        if (this.validatedDirectiveNames.contains(directiveName)) {
            addDiagnosticError(DIRECTIVE_NAME_ALREADY_IN_USE, location, directiveName);
            return;
        }
        this.validatedDirectiveNames.add(directiveName);
    }

    private void validateDirectiveConfigOnField(MappingConstructorExpressionNode expressionNode,
                                                SpecificFieldNode specificFieldNode, Location location) {
        if (specificFieldNode.valueExpr().isEmpty()) {
            return;
        }
        Location onValueLocation = specificFieldNode.valueExpr().get().location();
        SyntaxKind syntaxKind = specificFieldNode.valueExpr().get().kind();
        if (syntaxKind != SyntaxKind.QUALIFIED_NAME_REFERENCE && syntaxKind != SyntaxKind.LIST_CONSTRUCTOR
                && syntaxKind != SyntaxKind.STRING_LITERAL) {
            addDiagnosticWarning(PASSING_REFERENCE_FOR_ON_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED, location);
            return;
        }
        readOnFieldValues(specificFieldNode.valueExpr().get());
        validateOnFieldValues(onValueLocation == null ? expressionNode.location() : onValueLocation);
    }

    private void readOnFieldValues(ExpressionNode expressionNode) {
        if (expressionNode.kind() == SyntaxKind.QUALIFIED_NAME_REFERENCE) {
            this.onFieldValues.add(expressionNode.toString().split(SyntaxKind.COLON_TOKEN.stringValue())[1].trim());
        } else if (expressionNode.kind() == SyntaxKind.LIST_CONSTRUCTOR) {
            ListConstructorExpressionNode listConstructorExpressionNode
                    = (ListConstructorExpressionNode) expressionNode;
            for (Node member : listConstructorExpressionNode.expressions()) {
                if (member.kind() == SyntaxKind.STRING_LITERAL) {
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
            if (!isSupportedOnFieldLocation(onFieldValue)) {
                addDiagnosticWarning(DIRECTIVE_LOCATION_NOT_SUPPORTED, valueLocation, onFieldValue);
            }
        }
    }

    private boolean isSupportedOnFieldLocation(String onFieldValue) {
        switch (onFieldValue) {
            case QUERY_ON_FIELD_VALUE:
            case MUTATION_ON_FIELD_VALUE:
            case SUBSCRIPTION_ON_FIELD_VALUE:
            case FIELD_ON_FIELD_VALUE:
                return true;
        }
        return false;
    }

    private String getNameFromDirectiveConfigNameField(SpecificFieldNode specificFieldNode, Location location) {
        if (specificFieldNode.valueExpr().isEmpty()) {
            addDiagnosticWarning(PASSING_SHORT_HAND_NOTATION_FOR_DIRECTIVE_CONFIG_NOT_SUPPORTED, location);
            return null;
        }
        if (specificFieldNode.valueExpr().get().kind() == SyntaxKind.STRING_TEMPLATE_EXPRESSION) {
            addDiagnosticWarning(PASSING_STRING_TEMPLATE_FOR_NAME_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED, location);
            return null;
        }
        if (specificFieldNode.valueExpr().get().kind() != SyntaxKind.STRING_LITERAL) {
            addDiagnosticWarning(PASSING_NON_STRING_VALUE_FOR_NAME_FIELD_IN_DIRECTIVE_CONFIG_NOT_SUPPORTED, location);
            return null;
        }
        BasicLiteralNode basicLiteralNode = (BasicLiteralNode) specificFieldNode.valueExpr().get();
        return getValueFromStringLiteral(basicLiteralNode);
    }

    private void addDiagnosticWarning(CompilationDiagnostic compilationDiagnostic, Location location, Object... args) {
        updateContext(this.context, compilationDiagnostic, location, args);
    }

    private void validateDirectiveName(String directiveName, Location location) {
        if (!directiveName.matches(GRAPHQL_IDENTIFIER_REGEX)) {
            addDiagnosticError(INVALID_DIRECTIVE_NAME, location, directiveName);
        }
    }

    private void validateDirectiveServiceMember(Node node, Location location, String directiveClassName) {
        if (this.context.semanticModel().symbol(node).isEmpty()) {
            return;
        }
        Symbol symbol = this.context.semanticModel().symbol(node).get();
        if (symbol.kind() == SymbolKind.METHOD) {
            MethodSymbol methodSymbol = (MethodSymbol) symbol;
            if (isRemoteMethod(methodSymbol)) {
                validateRemoteMethod(methodSymbol, location);
            } else if (isInitMethod(methodSymbol)) {
                validateInitMethod(methodSymbol, location);
                validateDirectiveInputs(methodSymbol, location, directiveClassName);
            }
        } else if (symbol.kind() == SymbolKind.RESOURCE_METHOD) {
            ResourceMethodSymbol resourceMethodSymbol = (ResourceMethodSymbol) symbol;
            String resourceMethodSignature = resourceMethodSymbol.signature();
            addDiagnosticError(INVALID_RESOURCE_METHOD_INSIDE_DIRECTIVE, getLocation(resourceMethodSymbol, location),
                               resourceMethodSignature);
        }
    }

    private void validateDirectiveInputs(MethodSymbol methodSymbol, Location location, String directiveClassName) {
        FunctionTypeSymbol functionTypeSymbol = methodSymbol.typeDescriptor();
        if (functionTypeSymbol.params().isPresent()) {
            List<ParameterSymbol> parameterSymbols = functionTypeSymbol.params().get();
            for (ParameterSymbol parameter : parameterSymbols) {
                Location inputLocation = getLocation(parameter, location);
                this.inputTypeValidator.validateDirectiveInputParameterType(parameter.typeDescriptor(), inputLocation,
                                                                            directiveClassName);
            }
        }
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
        if (returnTypeKind != TypeDescKind.ANYDATA && returnTypeKind != TypeDescKind.ERROR && !isValidUnionReturnType(
                returnTypedesc.get())) {
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

    private String getOnFieldValueMapping(String remoteMethodName) {
        return this.onFieldRemoteMethodMapping.getOrDefault(remoteMethodName, null);
    }

    private void validateOnFieldToRemoteMethodMapping(Location location, String directiveClassName) {
        for (String onFieldValue : this.onFieldValues) {
            if (isSupportedOnFieldLocation(onFieldValue) && !this.remoteMethodNames.contains(
                    getRemoteMethodMapping(onFieldValue))) {
                addDiagnosticError(NO_REMOTE_METHOD_FOUND_FOR_ON_FIELD_VALUE, location, directiveClassName,
                                   onFieldValue);
            }
        }
    }

    private String getRemoteMethodMapping(String fieldName) {
        return this.onFieldRemoteMethodMapping.getOrDefault(fieldName, null);
    }

    public boolean isErrorOccurred() {
        return this.errorOccurred || this.inputTypeValidator.isErrorOccurred();
    }
}
