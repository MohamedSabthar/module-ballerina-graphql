package io.ballerina.stdlib.graphql.compiler.service.validator;


import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ParameterKind;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.syntax.tree.DefaultableParameterNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.ParameterNode;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.Project;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.Collection;
import java.util.Optional;

/**
 * Find ResourceConfig AnnotationNode node from the syntax tree.
 */
public class DefaultableParameterNodeFinder {
    private final MethodSymbol methodSymbol;
    private final ParameterSymbol parameterSymbol;
    private final SemanticModel semanticModel;
    private final Project project;
    private final ModuleId moduleId;

    public DefaultableParameterNodeFinder(SemanticModel semanticModel, Project project, ModuleId moduleId,
                                          MethodSymbol methodSymbol,
                                          ParameterSymbol parameterSymbol) {
        this.semanticModel = semanticModel;
        this.methodSymbol = methodSymbol;
        this.project = project;
        this.moduleId = moduleId;
        this.parameterSymbol = parameterSymbol;
    }

    public Optional<DefaultableParameterNode> getDeflatableParameterNode() {
        if (this.parameterSymbol.paramKind() != ParameterKind.DEFAULTABLE) {
            return Optional.empty();
        }
        Module currentModule = this.project.currentPackage().module(this.moduleId);
        Collection<DocumentId> documentIds = currentModule.documentIds();
        MethodDefinitionNodeVisitor methodDefinitionNodeVisitor = new MethodDefinitionNodeVisitor(this.semanticModel,
                                                                                                  this.methodSymbol,
                                                                                                  this.parameterSymbol);
        for (DocumentId documentId : documentIds) {
            Node rootNode = currentModule.document(documentId).syntaxTree().rootNode();
            rootNode.accept(methodDefinitionNodeVisitor);
            if (methodDefinitionNodeVisitor.getParameterNode().isPresent()) {
                break;
            }
        }
        Optional<ParameterNode> parameterNode = methodDefinitionNodeVisitor.getParameterNode();
        return parameterNode.map(node -> (DefaultableParameterNode) node);
    }
}
