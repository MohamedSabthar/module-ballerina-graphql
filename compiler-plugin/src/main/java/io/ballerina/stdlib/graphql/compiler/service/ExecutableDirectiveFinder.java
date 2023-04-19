package io.ballerina.stdlib.graphql.compiler.service;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.BasicLiteralNode;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.ExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingFieldNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.SpecificFieldNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.Project;
import io.ballerina.stdlib.graphql.compiler.service.validator.ExecutableDirectiveNodeVisitor;

import java.util.Collection;
import java.util.Optional;

import static io.ballerina.stdlib.graphql.compiler.Utils.getDirectiveConfigAnnotationNode;
import static io.ballerina.stdlib.graphql.compiler.Utils.getValueFromStringLiteral;
import static io.ballerina.stdlib.graphql.compiler.Utils.hasDirectiveConfig;
import static io.ballerina.stdlib.graphql.compiler.Utils.hasDirectiveTypeInclusion;

/**
 * Validate Executable directives in Ballerina GraphQL services.
 */
public class ExecutableDirectiveFinder {

    private static final String NAME = "name";
    private final ClassSymbol classSymbol;
    private final SemanticModel semanticModel;
    private final Project project;
    private final ModuleId moduleId;
    private String directiveName;

    public ExecutableDirectiveFinder(SemanticModel semanticModel, ClassSymbol classSymbol, Project project,
                                     ModuleId moduleID) {
        this.semanticModel = semanticModel;
        this.classSymbol = classSymbol;
        this.project = project;
        this.moduleId = moduleID;
    }

    public Optional<ClassDefinitionNode> getDirectiveNode() {
        if (classSymbol.getName().isEmpty() || !hasDirectiveTypeInclusionOrDirectiveConfig()) {
            return Optional.empty();
        }
        Optional<ClassDefinitionNode> classDefinitionNode = getClassDefinitionNodeFromModule();
        if (classDefinitionNode.isEmpty()) {
            return Optional.empty();
        }
        this.directiveName = this.classSymbol.getName().get();
        Optional<AnnotationNode> annotationNode = getDirectiveConfigAnnotationNode(this.semanticModel,
                                                                                   classDefinitionNode.get());
        if (annotationNode.isPresent() && annotationNode.get().annotValue().isPresent()) {
            String nameFieldValue = getDirectiveNameFromAnnotationValue(annotationNode.get().annotValue().get());
            if (nameFieldValue != null) {
                this.directiveName = nameFieldValue;
            }
        }
        return classDefinitionNode;
    }

    private String getDirectiveNameFromAnnotationValue(MappingConstructorExpressionNode expressionNode) {
        String directiveName = null;
        for (MappingFieldNode field : expressionNode.fields()) {
            if (field.kind() != SyntaxKind.SPECIFIC_FIELD) {
                continue;
            }
            SpecificFieldNode specificFieldNode = (SpecificFieldNode) field;
            String fieldName = specificFieldNode.fieldName().toString().trim();
            if (fieldName.equals(NAME)) {
                if (specificFieldNode.valueExpr().isEmpty()) {
                    continue;
                }
                if (specificFieldNode.valueExpr().get().kind() != SyntaxKind.STRING_LITERAL) {
                    continue;
                }
                ExpressionNode stringLiteral = specificFieldNode.valueExpr().get();
                if (!(stringLiteral instanceof BasicLiteralNode)) {
                    continue;
                }
                BasicLiteralNode basicLiteralNode = (BasicLiteralNode) specificFieldNode.valueExpr().get();
                directiveName = getValueFromStringLiteral(basicLiteralNode);
            }
        }
        return directiveName;
    }

    private boolean hasDirectiveTypeInclusionOrDirectiveConfig() {
        boolean hasDirectiveTypeInclusion = hasDirectiveTypeInclusion(this.classSymbol);
        boolean hasDirectiveConfig = hasDirectiveConfig(this.classSymbol);
        return hasDirectiveTypeInclusion || hasDirectiveConfig;
    }

    private Optional<ClassDefinitionNode> getClassDefinitionNodeFromModule() {
        Module currentModule = this.project.currentPackage().module(this.moduleId);
        Collection<DocumentId> documentIds = currentModule.documentIds();
        ExecutableDirectiveNodeVisitor directiveVisitor = new ExecutableDirectiveNodeVisitor(this.semanticModel,
                                                                                             this.classSymbol);
        for (DocumentId documentId : documentIds) {
            Node rootNode = currentModule.document(documentId).syntaxTree().rootNode();
            rootNode.accept(directiveVisitor);
            if (directiveVisitor.getClassDefinitionNode().isPresent()) {
                break;
            }
        }
        return directiveVisitor.getClassDefinitionNode();
    }

    public String getDirectiveName() {
        if (this.directiveName == null) {
            throw new IllegalStateException("Directive name is not set");
        }
        return this.directiveName;
    }
}
