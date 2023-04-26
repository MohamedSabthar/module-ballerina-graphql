package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.NodeVisitor;

import java.util.Optional;

/**
 * Obtains ExecutableDirective node from the syntax tree.
 */
public class ExecutableDirectiveNodeVisitor extends NodeVisitor {
    private final ClassSymbol classSymbol;
    private final SemanticModel semanticModel;
    private ClassDefinitionNode classDefinitionNode;

    public ExecutableDirectiveNodeVisitor(SemanticModel semanticModel, ClassSymbol classSymbol) {
        this.semanticModel = semanticModel;
        this.classSymbol = classSymbol;
    }

    @Override
    public void visit(ClassDefinitionNode classDefinitionNode) {
        Optional<Symbol> classDefinitionSymbol = this.semanticModel.symbol(classDefinitionNode);
        if (classDefinitionSymbol.isPresent() && classDefinitionSymbol.get().equals(this.classSymbol)) {
            this.classDefinitionNode = classDefinitionNode;
        }
        this.visitSyntaxNode(classDefinitionNode);
    }

    public Optional<ClassDefinitionNode> getClassDefinitionNode() {
        if (this.classDefinitionNode == null) {
            return Optional.empty();
        }
        return Optional.of(this.classDefinitionNode);
    }
}
