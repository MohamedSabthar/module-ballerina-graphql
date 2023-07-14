package io.ballerina.stdlib.graphql.compiler.service.validator;


import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.AnnotationSymbol;
import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.Project;

import java.util.Collection;
import java.util.Optional;

/**
 * Find EntityAnnotationNode node from the syntax tree.
 */
public class EntityAnnotationFinder {

    private final AnnotationSymbol annotationSymbol;
    private final SemanticModel semanticModel;
    private final Project project;
    private final ModuleId moduleId;

    public EntityAnnotationFinder(SemanticModel semanticModel, AnnotationSymbol annotationSymbol, Project project,
                                  ModuleId moduleID) {
        this.semanticModel = semanticModel;
        this.annotationSymbol = annotationSymbol;
        this.project = project;
        this.moduleId = moduleID;
    }

    public Optional<AnnotationNode> find() {
        if (annotationSymbol.getName().isEmpty()) {
            return Optional.empty();
        }
        return getAnnotationNodeFromModule();
    }

    private Optional<AnnotationNode> getAnnotationNodeFromModule() {
        Module currentModule = this.project.currentPackage().module(this.moduleId);
        Collection<DocumentId> documentIds = currentModule.documentIds();
        AnnotationNodeVisitor directiveVisitor = new AnnotationNodeVisitor(this.semanticModel, this.annotationSymbol);
        for (DocumentId documentId : documentIds) {
            Node rootNode = currentModule.document(documentId).syntaxTree().rootNode();
            rootNode.accept(directiveVisitor);
            if (directiveVisitor.getNode().isPresent()) {
                break;
            }
        }
        return directiveVisitor.getNode();
    }
}