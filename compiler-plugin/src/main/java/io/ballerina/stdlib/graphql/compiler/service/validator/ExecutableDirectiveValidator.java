package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.symbols.AnnotationSymbol;
import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.ResourceMethodSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.BasicLiteralNode;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.ExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingFieldNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.NodeList;
import io.ballerina.compiler.syntax.tree.SpecificFieldNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic;
import io.ballerina.tools.diagnostics.Location;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import static io.ballerina.stdlib.graphql.commons.utils.Utils.isGraphqlModuleSymbol;
import static io.ballerina.stdlib.graphql.compiler.Utils.isRemoteMethod;
import static io.ballerina.stdlib.graphql.compiler.Utils.isServiceObjectReference;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_CONFIG_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.DIRECTIVE_TYPE_INCLUSION_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.INVALID_REMOTE_METHOD_INSIDE_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.INVALID_REMOTE_METHOD_SIGNATURE_FOUND_IN_DIRECTIVE_SERVICE_CLASS;
import static io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic.INVALID_RESOURCE_METHOD_INSIDE_DIRECTIVE;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.getLocation;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.updateContext;

/**
 * Validate Executable directives in Ballerina GraphQL services.
 */
public class ExecutableDirectiveValidator {

    private static final String DIRECTIVE = "Directive";
    private static final String DIRECTIVE_CONFIG = "DirectiveConfig";
    private static final String APPLY_ON_QUERY = "applyOnQuery";
    private static final String APPLY_ON_MUTATION = "applyOnMutation";
    private static final String APPLY_ON_SUBSCRIPTION = "applyOnSubscription";
    private static final String APPLY_ON_FIELD = "applyOnField";
    private static final String CONTEXT = "Context";
    private static final String FIELD = "Field";
    private final ClassSymbol classSymbol;
    private final SyntaxNodeAnalysisContext context;
    private boolean errorOccurred;
    private String directiveName;

    public ExecutableDirectiveValidator(SyntaxNodeAnalysisContext context, ClassSymbol classSymbol) {
        this.context = context;
        this.classSymbol = classSymbol;
        this.errorOccurred = false;
    }

    public static boolean hasDirectiveConfig(ClassSymbol classSymbol) {
        return classSymbol.annotations().stream().filter(ExecutableDirectiveValidator::isDirectiveConfig).findFirst()
                .stream().findFirst().isPresent();
    }

    public static boolean hasDirectiveTypeInclusion(ClassSymbol classSymbol) {
        return classSymbol.typeInclusions().stream().filter(ExecutableDirectiveValidator::isGraphqlExecutableDirective)
                .findFirst().stream().findAny().isPresent();
    }

    private static boolean isDirectiveConfig(AnnotationSymbol annotationSymbol) {
        if (annotationSymbol.getName().isEmpty()) {
            return false;
        }
        return annotationSymbol.getName().get().equals(DIRECTIVE_CONFIG) && isGraphqlModuleSymbol(annotationSymbol);
    }

    private static boolean isGraphqlExecutableDirective(TypeSymbol typeSymbol) {
        if (typeSymbol.getName().isEmpty() || !isServiceObjectReference(typeSymbol)) {
            return false;
        }
        return typeSymbol.getName().get().equals(DIRECTIVE) && isGraphqlModuleSymbol(typeSymbol);
    }

    public void validate() {
        checkForDirectiveTypeInclusionAndDirectiveConfig();
        Optional<ClassDefinitionNode> classDefinitionNode = getClassDefinitionNodeFromModule();
        if (classDefinitionNode.isEmpty()) {
            return;
        }

        // noinspection OptionalGetWithoutIsPresent
        this.directiveName = classSymbol.getName().get();

        NodeList<Node> members = classDefinitionNode.get().members();
        Location location = classDefinitionNode.get().location();
        for (Node member : members) {
            validateDirectiveServiceMember(member, location);
        }

        // TODO: validate mapping between directiveConfig and service remote methods
        AnnotationNode directiveConfigAnnotationNode = getDirectiveConfigAnnotationNode(classDefinitionNode.get());
        MappingConstructorExpressionNode expressionNode = directiveConfigAnnotationNode.annotValue().get();
        for (MappingFieldNode field : expressionNode.fields()) {
            if (field.kind() != SyntaxKind.SPECIFIC_FIELD) {
                // TODO: add warning and continue
                continue;
            }
            SpecificFieldNode specificFieldNode = (SpecificFieldNode) field;
            String fieldName = specificFieldNode.fieldName().toString().trim();

            // TODO: obtain 'on field values, obtain name field value
            // validate them

            if (fieldName.equals("name")) {
                if (specificFieldNode.valueExpr().isEmpty()) {
                    // add error
                    continue;
                }
                if (specificFieldNode.valueExpr().get().kind() != SyntaxKind.STRING_LITERAL) {
                    // add warning
                    continue;
                }
                ExpressionNode stringLiteral = specificFieldNode.valueExpr().get();
                if (!(stringLiteral instanceof BasicLiteralNode)) {
                    // add warning
                    continue;
                }
                BasicLiteralNode basicLiteralNode = (BasicLiteralNode) specificFieldNode.valueExpr().get();
                String directiveName = basicLiteralNode.toSourceCode().strip();
                directiveName = directiveName.substring(1, directiveName.length() - 1); // remove quotes
                if (!isValidDirectiveName(directiveName)) {
                    // add error
                    continue;
                }
                this.directiveName = directiveName;
            }
        }
    }

    private boolean isValidDirectiveName(String directiveName) {
        return directiveName.matches("[_A-Za-z]\\w*");
    }

    private AnnotationNode getDirectiveConfigAnnotationNode(ClassDefinitionNode classDefinitionNode) {
        // noinspection OptionalGetWithoutIsPresent
        return classDefinitionNode.metadata().get().annotations().stream().filter(this::isDirectiveConfigAnnotationNode)
                .findFirst().get();
    }

    private boolean isDirectiveConfigAnnotationNode(AnnotationNode annotationNode) {
        Optional<Symbol> symbol = this.context.semanticModel().symbol(annotationNode);
        if (symbol.isEmpty()) {
            return false;
        }
        AnnotationSymbol annotationSymbol = (AnnotationSymbol) symbol.get();
        if (annotationSymbol.getName().isEmpty()) {
            return false;
        }
        return annotationSymbol.getName().get().equals(DIRECTIVE_CONFIG) && isGraphqlModuleSymbol(annotationSymbol);
    }

    private void checkForDirectiveTypeInclusionAndDirectiveConfig() {
        boolean hasDirectiveTypeInclusion = hasDirectiveTypeInclusion(this.classSymbol);
        boolean hasDirectiveConfig = hasDirectiveConfig(this.classSymbol);
        // noinspection OptionalGetWithoutIsPresent
        Location location = this.classSymbol.getLocation().get();
        // noinspection OptionalGetWithoutIsPresent
        String className = this.classSymbol.getName().get();
        if (hasDirectiveTypeInclusion && !hasDirectiveConfig) {
            addDiagnostic(DIRECTIVE_CONFIG_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS, location, className);
            this.errorOccurred = true;
        } else if (!hasDirectiveTypeInclusion) {
            addDiagnostic(DIRECTIVE_TYPE_INCLUSION_NOT_FOUND_IN_DIRECTIVE_SERVICE_CLASS, location, className);
            this.errorOccurred = true;
        }
    }

    public boolean isErrorOccurred() {
        return this.errorOccurred;
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
            }
        } else if (symbol.kind() == SymbolKind.RESOURCE_METHOD) {
            ResourceMethodSymbol resourceMethodSymbol = (ResourceMethodSymbol) symbol;
            String resourceMethodSignature = resourceMethodSymbol.signature();
            addDiagnostic(INVALID_RESOURCE_METHOD_INSIDE_DIRECTIVE, getLocation(resourceMethodSymbol, location),
                          resourceMethodSignature);
            this.errorOccurred = true;
        }
        // TODO: validate init method parameters to be graphql input types
    }

    private void validateRemoteMethod(MethodSymbol methodSymbol, Location location) {
        // noinspection OptionalGetWithoutIsPresent
        String methodName = methodSymbol.getName().get();
        if (!isAllowedRemoteMethodName(methodName)) {
            addDiagnostic(INVALID_REMOTE_METHOD_INSIDE_DIRECTIVE, getLocation(methodSymbol, location),
                          methodSymbol.signature());
            this.errorOccurred = true;
            return;
        }
        validateRemoteMethodSignature(methodSymbol, location);
    }

    private void validateRemoteMethodSignature(MethodSymbol methodSymbol, Location location) {
        // noinspection OptionalGetWithoutIsPresent
        String methodName = methodSymbol.getName().get();
        Optional<List<ParameterSymbol>> params = methodSymbol.typeDescriptor().params();
        if (params.isEmpty() || params.get().size() != 2) {
            addDiagnostic(INVALID_REMOTE_METHOD_SIGNATURE_FOUND_IN_DIRECTIVE_SERVICE_CLASS,
                          getLocation(methodSymbol, location), methodSymbol.signature(), methodName);
            this.errorOccurred = true;
            return;
        }
        if (!isExpectedParamType(params.get().get(0), CONTEXT)) {
            addDiagnostic(INVALID_REMOTE_METHOD_SIGNATURE_FOUND_IN_DIRECTIVE_SERVICE_CLASS,
                          getLocation(methodSymbol, location), methodSymbol.signature(), methodName);
            this.errorOccurred = true;
        }
        if (!isExpectedParamType(params.get().get(1), FIELD)) {
            addDiagnostic(INVALID_REMOTE_METHOD_SIGNATURE_FOUND_IN_DIRECTIVE_SERVICE_CLASS,
                          getLocation(methodSymbol, location), methodSymbol.signature(), methodName);
            this.errorOccurred = true;
        }
        Optional<TypeSymbol> returnTypedesc = methodSymbol.typeDescriptor().returnTypeDescriptor();
        if (returnTypedesc.isEmpty()) {
            addDiagnostic(INVALID_REMOTE_METHOD_SIGNATURE_FOUND_IN_DIRECTIVE_SERVICE_CLASS,
                          getLocation(methodSymbol, location), methodSymbol.signature(), methodName);
            this.errorOccurred = true;
        }
        // TODO: validate return type
//        if (!returnTypedesc.get().subtypeOf()) {
//            addDiagnostic(INVALID_REMOTE_METHOD_SIGNATURE_FOUND_IN_DIRECTIVE_SERVICE_CLASS,
//                          getLocation(methodSymbol, location), methodSymbol.signature(), methodName);
//            this.errorOccurred = true;
//        }
    }

    private boolean isExpectedParamType(ParameterSymbol parameterSymbol, String expectedTypeName) {
        if (parameterSymbol.typeDescriptor().getName().isEmpty()) {
            return false;
        }
        TypeSymbol typeDescriptor = parameterSymbol.typeDescriptor();
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

    private Optional<ClassDefinitionNode> getClassDefinitionNodeFromModule() {
        Module currentModule = this.context.currentPackage().module(this.context.moduleId());
        Collection<DocumentId> documentIds = currentModule.documentIds();
        ExecutableDirectiveVisitor directiveVisitor = new ExecutableDirectiveVisitor(this.context, this.classSymbol);
        for (DocumentId documentId : documentIds) {
            Node rootNode = currentModule.document(documentId).syntaxTree().rootNode();
            rootNode.accept(directiveVisitor);
            if (directiveVisitor.getClassDefinitionNode().isPresent()) {
                break;
            }
        }
        return directiveVisitor.getClassDefinitionNode();
    }

    private void addDiagnostic(CompilationDiagnostic compilationDiagnostic, Location location, Object... args) {
        updateContext(this.context, compilationDiagnostic, location, args);
    }

    public String getDirectiveName() {
        if (this.directiveName == null) {
            throw new IllegalStateException("Directive name is not set");
        }
        return this.directiveName;
    }
}
