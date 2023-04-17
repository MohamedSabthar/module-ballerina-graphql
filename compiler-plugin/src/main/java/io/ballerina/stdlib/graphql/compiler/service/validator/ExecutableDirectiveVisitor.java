package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.NodeVisitor;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.Optional;

/**
 * Obtains ExecutableDirective node from the syntax tree.
 */
public class ExecutableDirectiveVisitor extends NodeVisitor {
    private final SyntaxNodeAnalysisContext context;
    private final ClassSymbol classSymbol;
    private ClassDefinitionNode classDefinitionNode;

    public ExecutableDirectiveVisitor(SyntaxNodeAnalysisContext context, ClassSymbol classSymbol) {
        this.context = context;
        this.classSymbol = classSymbol;
    }

    @Override
    public void visit(ClassDefinitionNode classDefinitionNode) {
        Optional<Symbol> classDefinitionSymbol = this.context.semanticModel().symbol(classDefinitionNode);
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
