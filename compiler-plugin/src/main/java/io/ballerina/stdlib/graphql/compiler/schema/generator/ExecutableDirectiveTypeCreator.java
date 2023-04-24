package io.ballerina.stdlib.graphql.compiler.schema.generator;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.BasicLiteralNode;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.ListConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingFieldNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.SpecificFieldNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.stdlib.graphql.commons.types.Directive;
import io.ballerina.stdlib.graphql.commons.types.DirectiveLocation;
import io.ballerina.stdlib.graphql.commons.types.InputValue;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static io.ballerina.stdlib.graphql.compiler.Utils.getDirectiveConfigAnnotationNode;
import static io.ballerina.stdlib.graphql.compiler.Utils.getValueFromStringLiteral;
import static io.ballerina.stdlib.graphql.compiler.Utils.isInitMethod;

/**
 * Creates directive type from a Ballerina directive class node.
 */
public class ExecutableDirectiveTypeCreator {
    private static final String DIRECTIVE_NAME_FIELD = "name";
    private static final String DIRECTIVE_ON_FIELD = "on";
    private final TypeCreator typeCreator;
    private final List<String> onFieldValues = new ArrayList<>();
    private final Map<String, ParameterSymbol> parameters = new HashMap<>();
    private final ClassDefinitionNode directiveNode;
    private final SemanticModel semanticModel;
    private String directiveName;

    public ExecutableDirectiveTypeCreator(SemanticModel semanticModel, String directiveClassName,
                                          ClassDefinitionNode directiveNode, TypeCreator typeCreator) {
        this.semanticModel = semanticModel;
        this.directiveName = directiveClassName;
        this.directiveNode = directiveNode;
        this.typeCreator = typeCreator;
    }

    public Directive generate() {
        readAnnotation();
        readInitMethodParams();
        if (this.directiveName == null) {
            return null;
        }

        List<DirectiveLocation> directiveLocations = new ArrayList<>();
        for (String onFieldValue : this.onFieldValues) {
            directiveLocations.add(DirectiveLocation.valueOf(onFieldValue));
        }

        Directive directive = new Directive(this.directiveName, "", directiveLocations);
        for (Map.Entry<String, ParameterSymbol> entry : this.parameters.entrySet()) {
            // TODO: obtain description from documentation
            // TODO: add description
            InputValue inputValue = this.typeCreator.getArg(entry.getKey(), "", entry.getValue());
            directive.addArg(inputValue);
        }
        return directive;
    }

    private void readAnnotation() {
        Optional<AnnotationNode> configAnnotationNode = getDirectiveConfigAnnotationNode(this.semanticModel,
                                                                                         this.directiveNode);
        Optional<MappingConstructorExpressionNode> annotationValue = configAnnotationNode.get().annotValue();
        for (MappingFieldNode field : annotationValue.get().fields()) {
            if (field.kind() != SyntaxKind.SPECIFIC_FIELD) {
                continue;
            }
            SpecificFieldNode specificFieldNode = (SpecificFieldNode) field;
            String fieldName = specificFieldNode.fieldName().toString().trim();
            if (fieldName.equals(DIRECTIVE_NAME_FIELD)) {
                if (specificFieldNode.valueExpr().isEmpty()) {
                    continue;
                }
                if (specificFieldNode.valueExpr().get().kind() != SyntaxKind.STRING_LITERAL) {
                    continue;
                }
                BasicLiteralNode basicLiteralNode = (BasicLiteralNode) specificFieldNode.valueExpr().get();
                this.directiveName = getValueFromStringLiteral(basicLiteralNode);
            } else if (fieldName.equals(DIRECTIVE_ON_FIELD)) {
                var expressionNode = specificFieldNode.valueExpr().get();
                if (expressionNode.kind() == SyntaxKind.QUALIFIED_NAME_REFERENCE) {
                    this.onFieldValues.add(
                            expressionNode.toString().split(SyntaxKind.COLON_TOKEN.stringValue())[1].trim());
                } else if (expressionNode.kind() == SyntaxKind.LIST_CONSTRUCTOR) {
                    ListConstructorExpressionNode listConstructorExpressionNode
                            = (ListConstructorExpressionNode) expressionNode;
                    for (Node member : listConstructorExpressionNode.expressions()) {
                        if (member.kind() == SyntaxKind.STRING_LITERAL) {
                            String fieldValue = getValueFromStringLiteral((BasicLiteralNode) member);
                            this.onFieldValues.add(fieldValue);
                        } else if (member.kind() == SyntaxKind.QUALIFIED_NAME_REFERENCE) {
                            this.onFieldValues.add(
                                    member.toString().split(SyntaxKind.COLON_TOKEN.stringValue())[1].trim());
                        }
                    }
                }
            }
        }
    }

    private void readInitMethodParams() {
        for (Node node : this.directiveNode.members()) {
            if (this.semanticModel.symbol(node).isEmpty()) {
                continue;
            }
            Symbol symbol = this.semanticModel.symbol(node).get();
            if (symbol.kind() == SymbolKind.METHOD) {
                MethodSymbol methodSymbol = (MethodSymbol) symbol;
                if (!isInitMethod(methodSymbol)) {
                    continue;
                }
                var params = methodSymbol.typeDescriptor().params();
                if (params.isEmpty()) {
                    return;
                }
                for (var param : params.get()) {
                    this.parameters.put(param.getName().get(), param);
                }
            }
        }
    }


    public Map<String, ParameterSymbol> getInitMethodParameters() {
        return this.parameters;
    }
}
