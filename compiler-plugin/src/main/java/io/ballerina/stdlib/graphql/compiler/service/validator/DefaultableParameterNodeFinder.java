/*
 * Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
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

import java.util.ArrayList;
import java.util.Optional;

/**
 * Find DefaultableParameterNode from the syntax tree.
 */
public class DefaultableParameterNodeFinder {
    private final MethodSymbol methodSymbol;
    private final ParameterSymbol parameterSymbol;
    private final SemanticModel semanticModel;
    private final Project project;
    private final ModuleId moduleId;

    public DefaultableParameterNodeFinder(SemanticModel semanticModel, Project project, ModuleId moduleId,
                                          MethodSymbol methodSymbol, ParameterSymbol parameterSymbol) {
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
        ArrayList<DocumentId> documentIds = new ArrayList<>(currentModule.documentIds());
        documentIds.addAll(currentModule.testDocumentIds());
        MethodDefinitionNodeVisitor methodDefinitionNodeVisitor = new MethodDefinitionNodeVisitor(this.semanticModel,
                                                                                                  this.methodSymbol,
                                                                                                  this.parameterSymbol);
        for (DocumentId documentId : documentIds) {
            Node rootNode = currentModule.document(documentId).syntaxTree().rootNode();
            rootNode.accept(methodDefinitionNodeVisitor);
            Optional<ParameterNode> parameterNode = methodDefinitionNodeVisitor.getParameterNode();
            if (parameterNode.isPresent()) {
                return parameterNode.map(node -> (DefaultableParameterNode) node);
            }
        }
        return Optional.empty();
    }
}
