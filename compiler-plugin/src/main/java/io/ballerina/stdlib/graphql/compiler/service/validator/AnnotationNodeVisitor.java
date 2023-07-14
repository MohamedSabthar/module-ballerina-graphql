package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.AnnotationSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.NodeVisitor;

import java.util.Optional;

/**
 * Obtains EntityAnnotationNode node from the syntax tree.
 */
public class AnnotationNodeVisitor extends NodeVisitor {
    private final AnnotationSymbol annotationSymbol;
    private final SemanticModel semanticModel;
    private AnnotationNode annotationNode;

    public AnnotationNodeVisitor(SemanticModel semanticModel, AnnotationSymbol annotationSymbol) {
        this.semanticModel = semanticModel;
        this.annotationSymbol = annotationSymbol;
    }

    @Override
    public void visit(AnnotationNode annotationNode) {
        Optional<Symbol> classDefinitionSymbol = this.semanticModel.symbol(annotationNode);
        if (classDefinitionSymbol.isPresent() && classDefinitionSymbol.get().equals(this.annotationSymbol)) {
            this.annotationNode = annotationNode;
        }
    }

    public Optional<AnnotationNode> getNode() {
        if (this.annotationNode == null) {
            return Optional.empty();
        }
        return Optional.of(this.annotationNode);
    }
}