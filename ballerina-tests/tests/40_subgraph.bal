// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/graphql;
import ballerina/test;

@test:Config {
    groups: ["federation", "subgraph", "entity"]
}
isolated function testSubgrapWithValidQuery() returns error? {
    string document = string `{ stars { name } }`;
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    json response = check graphqlClient->execute(document);
    json expectedPayload = {data: {stars: [{name: "Absolutno*"}, {name: "Acamar"}, {name: "Achernar"}]}};
    assertJsonValuesWithOrder(response, expectedPayload);
}

@test:Config {
    groups: ["federation", "subgraph", "entity"]
}
isolated function testQueringEntityFieldOnSubgraph() returns error? {
    string document = check getGraphQLDocumentFromFile("quering_entity_field_on_subgrap.graphql");
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    json response = check graphqlClient->execute(document);
    json expectedPayload = {
        data: {
            _entities: [
                {name: "Acamar", constellation: "Acamar", designation: "θ1 Eridani A"},
                {name: "Absolutno*", constellation: "Absolutno*", designation: "XO-5"}
            ]
        }
    };
    assertJsonValuesWithOrder(response, expectedPayload);
}

@test:Config {
    groups: ["federation", "subgraph", "entity"]
}
isolated function testQueringEntityFieldWithNullArgument() returns error? {
    string document = string `{ _entities( representations: null ) { ... on Star { name } } }`;
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    json|graphql:ClientError response = graphqlClient->execute(document);
    test:assertTrue(response is graphql:InvalidDocumentError);
    graphql:InvalidDocumentError err = <graphql:InvalidDocumentError>response;
    string message = string `Expected value of type "[_Any!]!", found null.`;
    json locations = [{line: 1, column: 31}];
    json expectedResponse = [{message, locations}];
    test:assertEquals(err.detail().errors.toJson(), expectedResponse);
}

@test:Config {
    groups: ["federation", "subgraph", "entity"]
}
isolated function testQueringEntityFieldWithListOfNullValues() returns error? {
    string document = string `{ _entities( representations: [null] ) { ... on Star { name } } }`;
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    json|graphql:ClientError response = graphqlClient->execute(document);
    test:assertTrue(response is graphql:InvalidDocumentError);
    graphql:InvalidDocumentError err = <graphql:InvalidDocumentError>response;
    string message = string `_Any! cannot represent non _Any! value: null`;
    json locations = [{line: 1, column: 32}];
    json expectedResponse = [{message, locations}];
    test:assertEquals(err.detail().errors.toJson(), expectedResponse);
}

@test:Config {
    groups: ["federation", "subgraph", "entity"]
}
isolated function testQueringEntityFieldWithNullVariable() returns error? {
    string document = string `query ($rep: [_Any!]!) { _entities( representations: $rep ) { ... on Star { name } } }`;
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    map<json> variables = {rep: null};
    json|graphql:ClientError response = graphqlClient->execute(document, variables);
    test:assertTrue(response is graphql:InvalidDocumentError);
    graphql:InvalidDocumentError err = <graphql:InvalidDocumentError>response;
    string message = string `Variable rep expected value of type "[_Any!]!", found null`;
    json locations = [{line: 1, column: 55}];
    json expectedResponse = [{message, locations}];
    test:assertEquals(err.detail().errors.toJson(), expectedResponse);
}

@test:Config {
    groups: ["federation", "subgraph", "entity"]
}
isolated function testQueringEntityFieldWithLisOfNullVariable() returns error? {
    string document = string `query ($rep: [_Any!]!) { _entities( representations: $rep ) { ... on Star { name } } }`;
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    map<json> variables = {rep: [null]};
    json|graphql:ClientError response = graphqlClient->execute(document, variables);
    test:assertTrue(response is graphql:InvalidDocumentError);
    graphql:InvalidDocumentError err = <graphql:InvalidDocumentError>response;
    string message = string `representations: In element #0:Expected value of type "_Any!", found null.`;
    json locations = [{line: 1, column: 55}];
    json expectedResponse = [{message, locations}];
    test:assertEquals(err.detail().errors.toJson(), expectedResponse);
}

@test:Config {
    groups: ["federation", "subgraph", "entity"]
}
isolated function testQueringEntityFieldWithVariableOnSubgraph() returns error? {
    string document = check getGraphQLDocumentFromFile("quering_entity_field_with_variable_on_subgrap.graphql");
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    map<json> variables = {representations: [{__typename: "Star", name: "Acamar"}, {__typename: "Star", name: "Absolutno*"}]};
    json response = check graphqlClient->execute(document, variables);
    json expectedPayload = {
        data: {
            _entities: [
                {name: "Acamar", constellation: "Acamar", designation: "θ1 Eridani A"},
                {name: "Absolutno*", constellation: "Absolutno*", designation: "XO-5"}
            ]
        }
    };
    assertJsonValuesWithOrder(response, expectedPayload);
}

@test:Config {
    groups: ["federation", "subgraph", "entity", "introspection"]
}
isolated function testIntrospectionOnSubgraph() returns error? {
    string document = check getGraphQLDocumentFromFile("introspection_on_subgraph.graphql");
    string url = "localhost:9090/subgraph";
    graphql:Client graphqlClient = check new (url);
    map<json> variables = {representations: [{__typename: "Star", name: "Acamar"}, {__typename: "Star", name: "Absolutno*"}]};
    json response = check graphqlClient->execute(document, variables);
    json expectedPayload = check getJsonContentFromFile("introspection_on_subgraph.json");
    assertJsonValuesWithOrder(response, expectedPayload);
}

// TODO: test quering sdl
// TODO: test querying _Any field without __representation
// TODO: test querying with incompatible _Any field (non json object and nulls)
