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

package io.ballerina.stdlib.graphql.compiler.schema.generator;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ResourceMethodSymbol;
import io.ballerina.compiler.api.symbols.ServiceDeclarationSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TypeDefinitionSymbol;
import io.ballerina.compiler.syntax.tree.ClassDefinitionNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.ObjectConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.ServiceDeclarationNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.Project;
import io.ballerina.stdlib.graphql.commons.types.DefaultDirective;
import io.ballerina.stdlib.graphql.commons.types.Description;
import io.ballerina.stdlib.graphql.commons.types.Directive;
import io.ballerina.stdlib.graphql.commons.types.InputValue;
import io.ballerina.stdlib.graphql.commons.types.ScalarType;
import io.ballerina.stdlib.graphql.commons.types.Schema;
import io.ballerina.stdlib.graphql.commons.types.Type;
import io.ballerina.stdlib.graphql.commons.types.TypeKind;
import io.ballerina.stdlib.graphql.commons.types.TypeName;
import io.ballerina.stdlib.graphql.compiler.service.InterfaceEntityFinder;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Map;
import java.util.stream.Collectors;

import static io.ballerina.stdlib.graphql.compiler.Utils.getAccessor;
import static io.ballerina.stdlib.graphql.compiler.Utils.isFunctionDefinition;
import static io.ballerina.stdlib.graphql.compiler.Utils.isRemoteMethod;
import static io.ballerina.stdlib.graphql.compiler.Utils.isResourceMethod;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.getWrapperType;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.RESOURCE_FUNCTION_GET;

/**
 * Generates the GraphQL schema from a given, valid, Ballerina service.
 */
public class SchemaGenerator {

    private static final String IF_ARG_NAME = "if";
    private static final String REASON_ARG_NAME = "reason";

    private final Node serviceNode;
    private final InterfaceEntityFinder interfaceEntityFinder;
    private final Schema schema;
    private final SemanticModel semanticModel;
    private final TypeCreator typeCreator;

    public SchemaGenerator(Node serviceNode, InterfaceEntityFinder interfaceEntityFinder, SemanticModel semanticModel,
                           Project project, String description, boolean isSubgraph) {
        this.serviceNode = serviceNode;
        this.interfaceEntityFinder = interfaceEntityFinder;
        this.schema = new Schema(description, isSubgraph);
        this.semanticModel = semanticModel;
        this.typeCreator = new TypeCreator(interfaceEntityFinder, schema, project);
    }

    public Schema generate() {
        findRootTypes(this.serviceNode);
        findIntrospectionTypes();
        // TODO: add custom directives
        addCustomExecutableDirectives();
        addEntityTypes();
        return this.schema;
    }

    private void findIntrospectionTypes() {
        IntrospectionTypeCreator introspectionTypeCreator = new IntrospectionTypeCreator(this.schema);
        introspectionTypeCreator.addIntrospectionTypes();
        addDefaultDirectives();
    }

    private void addDefaultDirectives() {
        Directive include = new Directive(DefaultDirective.INCLUDE);
        include.addArg(getIfInputValue(Description.INCLUDE_IF));
        this.schema.addDirective(include);

        Directive skip = new Directive(DefaultDirective.SKIP);
        skip.addArg(getIfInputValue(Description.SKIP_IF));
        this.schema.addDirective(skip);

        Directive deprecated = new Directive(DefaultDirective.DEPRECATED);
        InputValue reason = new InputValue(REASON_ARG_NAME, this.typeCreator.addType(ScalarType.STRING),
                                           Description.DEPRECATED_REASON.getDescription(), null);
        deprecated.addArg(reason);
        this.schema.addDirective(deprecated);
    }

    private InputValue getIfInputValue(Description description) {
        Type type = getWrapperType(this.typeCreator.addType(ScalarType.BOOLEAN), TypeKind.NON_NULL);
        return new InputValue(IF_ARG_NAME, type, description.getDescription(), null);
    }

    private void findRootTypes(Node serviceNode) {
        Type queryType = this.typeCreator.addType(TypeName.QUERY);
        for (MethodSymbol methodSymbol : getMethods(serviceNode)) {
            if (isResourceMethod(methodSymbol)) {
                ResourceMethodSymbol resourceMethodSymbol = (ResourceMethodSymbol) methodSymbol;
                String accessor = getAccessor(resourceMethodSymbol);
                if (RESOURCE_FUNCTION_GET.equals(accessor)) {
                    queryType.addField(this.typeCreator.getField((resourceMethodSymbol)));
                } else {
                    Type subscriptionType = this.typeCreator.addType(TypeName.SUBSCRIPTION);
                    subscriptionType.addField(this.typeCreator.getField(resourceMethodSymbol));
                }
            } else if (isRemoteMethod(methodSymbol)) {
                Type mutationType = this.typeCreator.addType(TypeName.MUTATION);
                mutationType.addField(this.typeCreator.getField(methodSymbol));
            }
        }
        this.schema.setQueryType(queryType);
        if (this.schema.containsType(TypeName.MUTATION.getName())) {
            this.schema.setMutationType(this.schema.getType(TypeName.MUTATION.getName()));
        }
        if (this.schema.containsType(TypeName.SUBSCRIPTION.getName())) {
            this.schema.setSubscriptionType(this.schema.getType(TypeName.SUBSCRIPTION.getName()));
        }
    }

    private Collection<? extends MethodSymbol> getMethods(Node node) {
        if (node.kind() == SyntaxKind.SERVICE_DECLARATION) {
            return getMethods((ServiceDeclarationNode) node);
        }

        if (node.kind() == SyntaxKind.OBJECT_CONSTRUCTOR) {
            return getMethods((ObjectConstructorExpressionNode) node);
        }

        return new ArrayList<>();
    }

    private Collection<? extends MethodSymbol> getMethods(
            ObjectConstructorExpressionNode objectConstructorExpressionNode) {
        // noinspection OptionalGetWithoutIsPresent
        return objectConstructorExpressionNode.members().stream()
                .filter(member -> isFunctionDefinition(member) && semanticModel.symbol(member).isPresent())
                .map(methodNode -> (MethodSymbol) semanticModel.symbol(methodNode).get()).collect(Collectors.toList());
    }

    private Collection<? extends MethodSymbol> getMethods(ServiceDeclarationNode serviceDeclarationNode) {
        // ServiceDeclarationSymbol already validated. Therefore, no need to check isEmpty().
        // noinspection OptionalGetWithoutIsPresent
        ServiceDeclarationSymbol serviceDeclarationSymbol = (ServiceDeclarationSymbol) semanticModel.symbol(
                serviceDeclarationNode).get();
        return serviceDeclarationSymbol.methods().values();
    }

    private void addCustomExecutableDirectives() {
        Map<String, ClassDefinitionNode> directivesMap = this.interfaceEntityFinder.getExecutableDirectives();
        for (Map.Entry<String, ClassDefinitionNode> entry : directivesMap.entrySet()) {
            String className = entry.getKey();
            ClassDefinitionNode classDefinitionNode = entry.getValue();
            var generator = new ExecutableDirectiveTypeCreator(this.semanticModel, className, classDefinitionNode,
                                                               this.typeCreator);
            Directive directive = generator.generate();
            if (directive == null) {
                continue;
            }
            this.schema.addDirective(directive);
        }
    }

    private void addEntityTypes() {
        if (!this.schema.isSubgraph()) {
            return;
        }
        for (Map.Entry<String, Symbol> entry : this.interfaceEntityFinder.getEntities().entrySet()) {
            String entityName = entry.getKey();
            Symbol symbol = entry.getValue();
            if (symbol.kind() == SymbolKind.TYPE_DEFINITION) {
                this.schema.addEntity(this.typeCreator.getType(entityName, (TypeDefinitionSymbol) symbol));
            } else if (symbol.kind() == SymbolKind.CLASS) {
                this.schema.addEntity(this.typeCreator.getType(entityName, (ClassSymbol) symbol));
            }
        }
    }
}
