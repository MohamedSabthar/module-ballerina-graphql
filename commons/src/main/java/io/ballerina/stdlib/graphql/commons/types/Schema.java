/*
 * Copyright (c) 2022, WSO2 LLC. (http://www.wso2.org). All Rights Reserved.
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

package io.ballerina.stdlib.graphql.commons.types;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.ARGUMENT_DEFINITION;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.ENUM;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.ENUM_VALUE;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.FIELD_DEFINITION;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.INPUT_FIELD_DEFINITION;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.INPUT_OBJECT;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.INTERFACE;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.OBJECT;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.SCALAR;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.SCHEMA;
import static io.ballerina.stdlib.graphql.commons.types.DirectiveLocation.UNION;

/**
 * Represents the {@code Schema} type in GraphQL schema.
 */
public class Schema implements Serializable {
    private static final long serialVersionUID = 1L;
    private final String description;
    private final Map<String, Type> types;
    private final List<Directive> directives;
    private final List<Type> entities;
    private Type queryType;
    private Type mutationType = null;
    private Type subscriptionType = null;

    /**
     * Creates the schema.
     *
     * @param description - The description of the schema
     */
    public Schema(String description) {
        this.description = description;
        this.types = new LinkedHashMap<>();
        this.directives = new ArrayList<>();
        this.entities = new ArrayList<>();
    }

    /**
     * Adds a type to the schema and returns it. If the type name already exists, returns the existing type. If the
     * type name does not exist in the schema, creates the type and returns it.
     *
     * @param typeName - The name of the type
     * @param kind - The TypeKind of the type
     * @param description - The description of the type
     *
     * @return - The created or existing type with the provided name
     */
    public Type addType(String typeName, TypeKind kind, String description) {
        if (this.types.containsKey(typeName)) {
            return this.types.get(typeName);
        }
        Type type = new Type(typeName, kind, description);
        this.types.put(typeName, type);
        return type;
    }

    /**
     * Adds a Scalar type to the schema from a given ScalarType and returns it. If the scalar type already exist,
     * returns the existing scalar type.
     *
     * @param scalarType - The ScalarType to be added
     *
     * @return - The created or existing scalar type
     */
    public Type addType(ScalarType scalarType) {
        if (this.types.containsKey(scalarType.getName())) {
            return this.types.get(scalarType.getName());
        }
        Type type = new Type(scalarType.getName(), TypeKind.SCALAR, scalarType.getDescription());
        this.types.put(scalarType.getName(), type);
        return type;
    }

    public boolean containsType(String name) {
        return this.types.containsKey(name);
    }

    public Map<String, Type> getTypes() {
        return this.types;
    }

    public Type getType(String name) {
        return this.types.get(name);
    }

    public String getDescription() {
        return this.description;
    }

    public Type getQueryType() {
        return this.queryType;
    }

    public void setQueryType(Type type) {
        this.queryType = type;
    }

    public void setMutationType(Type type) {
        this.mutationType = type;
    }

    public Type getMutationType() {
        return this.mutationType;
    }

    public void setSubscriptionType(Type type) {
        this.subscriptionType = type;
    }

    public Type getSubscriptionType() {
        return this.subscriptionType;
    }

    public void addDirective(Directive directive) {
        this.directives.add(directive);
    }

    public List<Directive> getDirectives() {
        return this.directives;
    }

    public void addEntities(Map<String, Type> federatedEntities) {
        this.entities.addAll(federatedEntities.values());


        Type entity = addType("_Entity", TypeKind.UNION, null);
        this.entities.forEach(entity::addPossibleType);
        this.types.put("_Entity", entity);

        Type any = addType("_Any", TypeKind.SCALAR, null);
        Type fieldSet = addType("FieldSet", TypeKind.SCALAR, null);
        Type linkImport = addType("link__Import", TypeKind.SCALAR, null);

        Type linkPurpose = addType("link__Purpose", TypeKind.ENUM, null);
        linkPurpose.addEnumValue(new EnumValue("SECURITY", "`SECURITY` features provide"
                + " metadata necessary to securely resolve fields."));
        linkPurpose.addEnumValue(new EnumValue("EXECUTION", "`EXECUTION` features provide"
                + " metadata necessary for operation execution."));

        Type string = getType("String");
        Type nonNullableString = new Type(TypeKind.NON_NULL, string);

        Type service = addType("_Service", TypeKind.OBJECT, null);
        service.addField(new Field("sdl", nonNullableString));

        Field entities = new Field("_entities", new Type(TypeKind.NON_NULL, new Type(TypeKind.LIST, entity)));
        entities.addArg(new InputValue("representations", new Type(TypeKind.NON_NULL, new Type(TypeKind.LIST, new Type(
                TypeKind.NON_NULL, any))), null, null));
        Field serviceField = new Field("_service", new Type(TypeKind.NON_NULL, service));

        Type query = getQueryType();
        query.addField(entities);
        query.addField(serviceField);

        Directive external = new Directive("external", null, List.of(FIELD_DEFINITION, OBJECT));
        addDirective(external);

        Directive requires = new Directive("requires", null, List.of(FIELD_DEFINITION));
        InputValue fields = new InputValue("fields", new Type(TypeKind.NON_NULL, fieldSet), null, null);
        requires.addArg(fields);
        addDirective(requires);

        Directive provides = new Directive("provides", null, List.of(FIELD_DEFINITION));
        provides.addArg(fields);
        addDirective(provides);

        Directive key = new Directive("key", null, List.of(OBJECT, INTERFACE));
        key.addArg(fields);
        InputValue resolvable = new InputValue("resolvable", getType("Boolean"), null, "true");
        key.addArg(resolvable);
        addDirective(key);

        Directive link = new Directive("link", null, List.of(SCHEMA));
        InputValue url = new InputValue("url", nonNullableString, null, null);
        link.addArg(url);
        InputValue as = new InputValue("as", string, null, null);
        link.addArg(as);
        InputValue forInput = new InputValue("for", linkPurpose, null, null);
        link.addArg(forInput);
        InputValue importInput = new InputValue("import", new Type(TypeKind.LIST, linkImport), null, null);
        link.addArg(importInput);
        addDirective(link);

        Directive shareable = new Directive("shareable", null, List.of(OBJECT, FIELD_DEFINITION));
        addDirective(shareable);

        Directive inaccessible = new Directive("inaccessible", null,
                                               List.of(FIELD_DEFINITION, OBJECT, INTERFACE, UNION, ARGUMENT_DEFINITION,
                                                       SCALAR, ENUM, ENUM_VALUE, INPUT_OBJECT, INPUT_FIELD_DEFINITION));
        addDirective(inaccessible);

        Directive tag = new Directive("tag", null,
                                      List.of(FIELD_DEFINITION, INTERFACE, OBJECT, UNION, ARGUMENT_DEFINITION, SCALAR,
                                              ENUM, ENUM_VALUE, INPUT_OBJECT, INPUT_FIELD_DEFINITION));
        InputValue name = new InputValue("name", nonNullableString, null, null);
        tag.addArg(name);
        addDirective(tag);

        Directive override = new Directive("override", null, List.of(FIELD_DEFINITION));
        override.addArg(name);
        addDirective(override);

        Directive composeDirective = new Directive("composeDirective", null, List.of(SCHEMA));
        composeDirective.addArg(name);
        addDirective(composeDirective);

        Directive extendsDirective = new Directive("extends", null, List.of(OBJECT, INTERFACE));
        addDirective(extendsDirective);
    }

    public List<Type> getEntities() {
        return this.entities;
    }
}
