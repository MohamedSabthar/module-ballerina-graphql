package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.NodeVisitor;
import io.ballerina.compiler.syntax.tree.ParameterNode;

import java.util.Optional;

/**
 * Obtains ResourceConfig AnnotationNode node from the syntax tree.
 */
public class MethodDefinitionNodeVisitor extends NodeVisitor {
    private final SemanticModel semanticModel;
    private final MethodSymbol methodSymbol;
    private final ParameterSymbol parameterSymbol;
    private ParameterNode parameterNode;

    public MethodDefinitionNodeVisitor(SemanticModel semanticModel, MethodSymbol methodSymbol,
                                       ParameterSymbol parameterSymbol) {
        this.semanticModel = semanticModel;
        this.methodSymbol = methodSymbol;
        this.parameterSymbol = parameterSymbol;
    }

    @Override
    public void visit(FunctionDefinitionNode functionDefinitionNode) {
        if (this.parameterNode != null) {
            return;
        }
        Optional<Symbol> functionSymbol = this.semanticModel.symbol(functionDefinitionNode);
        if (functionSymbol.isEmpty() || functionSymbol.get().hashCode() != this.methodSymbol.hashCode()) {
            return;
        }
        for (ParameterNode parameterNode : functionDefinitionNode.functionSignature().parameters()) {
            if (this.semanticModel.symbol(parameterNode).isEmpty()) {
                continue;
            }
            Symbol symbol = this.semanticModel.symbol(parameterNode).get();
            if (symbol.kind() == SymbolKind.PARAMETER && symbol.hashCode() == this.parameterSymbol.hashCode()) {
                this.parameterNode = parameterNode;
            }
        }
    }

    public Optional<ParameterNode> getParameterNode() {
        if (this.parameterNode == null) {
            return Optional.empty();
        }
        return Optional.of(this.parameterNode);
    }
}
