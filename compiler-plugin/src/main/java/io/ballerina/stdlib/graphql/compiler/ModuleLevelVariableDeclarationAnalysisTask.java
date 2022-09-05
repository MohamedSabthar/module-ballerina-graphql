/*
 * Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.graphql.compiler;

import io.ballerina.compiler.api.symbols.VariableSymbol;
import io.ballerina.compiler.syntax.tree.IdentifierToken;
import io.ballerina.compiler.syntax.tree.ModuleVariableDeclarationNode;
import io.ballerina.compiler.syntax.tree.ObjectConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.QualifiedNameReferenceNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.compiler.syntax.tree.Token;
import io.ballerina.compiler.syntax.tree.TypeDescriptorNode;
import io.ballerina.compiler.syntax.tree.TypedBindingPatternNode;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.plugins.AnalysisTask;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.stdlib.graphql.compiler.schema.generator.SchemaGeneratorForObject;
import io.ballerina.stdlib.graphql.compiler.schema.types.Schema;
import io.ballerina.stdlib.graphql.compiler.service.InterfaceFinder;
import io.ballerina.stdlib.graphql.compiler.service.validator.ServiceObjectValidator;

import static io.ballerina.stdlib.graphql.compiler.Utils.PACKAGE_NAME;
import static io.ballerina.stdlib.graphql.compiler.Utils.SERVICE_NAME;
import static io.ballerina.stdlib.graphql.compiler.Utils.hasCompilationErrors;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.getDescription;

// cases:
// 1. module level var dec
// 2. local var dec
// 3. union val
// 4. assignment statements

/**
 * Validates a Ballerina GraphQL Service.
 */
public class ModuleLevelVariableDeclarationAnalysisTask implements AnalysisTask<SyntaxNodeAnalysisContext> {
//    private final Map<DocumentId, GraphqlModifierContext> modifierContextMap;

//    public ModuleLevelVariableDeclarationAnalysisTask(Map<DocumentId, GraphqlModifierContext> nodeMap) {
//        this.modifierContextMap = nodeMap;
//    }

    @Override
    public void perform(SyntaxNodeAnalysisContext context) {
        if (hasCompilationErrors(context)) {
            return;
        }

        if (!isModuleLevelGraphQLServiceDeclaration(context)) {
            return;
        }

        ModuleVariableDeclarationNode moduleVariableDeclarationNode = (ModuleVariableDeclarationNode) context.node();

        if (moduleVariableDeclarationNode.initializer().isEmpty()) {
            return;
        }
        ObjectConstructorExpressionNode graphqlServiceObjectNode
                = (ObjectConstructorExpressionNode) moduleVariableDeclarationNode.initializer().get();
        InterfaceFinder interfaceFinder = new InterfaceFinder();
        interfaceFinder.populateInterfaces(context);
        ServiceObjectValidator serviceObjectValidator = new ServiceObjectValidator(context, graphqlServiceObjectNode,
                interfaceFinder);
        serviceObjectValidator.validate();
        if (serviceObjectValidator.isErrorOccurred()) {
            return;
        }
        DocumentId documentId = context.documentId();
        String description = null;
        if (context.semanticModel().symbol(moduleVariableDeclarationNode).isPresent()) {
            VariableSymbol serviceVariableSymbol = (VariableSymbol) context.semanticModel()
                    .symbol(moduleVariableDeclarationNode).get();
            description = getDescription(serviceVariableSymbol);
        }
        Schema schema = generateSchema(interfaceFinder, graphqlServiceObjectNode, description, context);
//        addToModifierContextMap(documentId, node, schema);
    }

    private boolean isModuleLevelGraphQLServiceDeclaration(SyntaxNodeAnalysisContext context) {
        ModuleVariableDeclarationNode moduleVariableDeclarationNode = (ModuleVariableDeclarationNode) context.node();
        TypedBindingPatternNode typedBindingPatternNode = moduleVariableDeclarationNode.typedBindingPattern();
        TypeDescriptorNode typeDescriptorNode = typedBindingPatternNode.typeDescriptor();

        if (typeDescriptorNode.kind() != SyntaxKind.QUALIFIED_NAME_REFERENCE) {
            return false;
        }

        QualifiedNameReferenceNode qualifiedNameReferenceNode = (QualifiedNameReferenceNode) typeDescriptorNode;
        Token modulePrefixToken = qualifiedNameReferenceNode.modulePrefix();

        if (modulePrefixToken.kind() != SyntaxKind.IDENTIFIER_TOKEN) {
            return false;
        }

        if (!PACKAGE_NAME.equals(modulePrefixToken.text())) {
            return false;
        }

        IdentifierToken identifier = qualifiedNameReferenceNode.identifier();
        return SERVICE_NAME.equals(identifier.text());
    }

    private Schema generateSchema(InterfaceFinder interfaceFinder, ObjectConstructorExpressionNode serviceObjectNode,
                                  String description, SyntaxNodeAnalysisContext context) {
        SchemaGeneratorForObject schemaGenerator = new SchemaGeneratorForObject(serviceObjectNode, interfaceFinder,
                description, context);
        return schemaGenerator.generate();
    }

//    private void addToModifierContextMap(DocumentId documentId, ServiceDeclarationNode node, Schema schema) {
//        if (this.modifierContextMap.containsKey(documentId)) {
//            GraphqlModifierContext modifierContext = this.modifierContextMap.get(documentId);
//            modifierContext.add(node, schema);
//        } else {
//            GraphqlModifierContext modifierContext = new GraphqlModifierContext();
//            modifierContext.add(node, schema);
//            this.modifierContextMap.put(documentId, modifierContext);
//        }
//    }
}
