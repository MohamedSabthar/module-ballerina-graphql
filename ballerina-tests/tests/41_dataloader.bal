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
import ballerina/websocket;
import ballerina/test;

@test:Config {
    groups: ["dataloader", "query"]
}
isolated function testDataLoaderWithQuery() returns error? {
    string url = "localhost:9090/dataloader";
    graphql:Client graphqlClient = check new (url);
    string document = check getGraphqlDocumentFromFile("dataloader_with_query");
    json response = check graphqlClient->execute(document);
    json expectedPayload = check getJsonContentFromFile("dataloader_with_query");
    assertJsonValuesWithOrder(response, expectedPayload);
    lock {
        test:assertEquals(databaseHitForAuthorField, 1, "Database hit for author field is not 1");
        databaseHitForAuthorField = 0;
    }
    lock {
        test:assertEquals(databaseHitForBookField, 1, "Database hit for book field is not 1");
        databaseHitForBookField = 0;
    }
}

@test:Config {
    groups: ["dataloader", "query"]
}
isolated function testDataLoaderWithDifferentAliasForSameField() returns error? {
    string url = "localhost:9090/dataloader";
    graphql:Client graphqlClient = check new (url);
    string document = check getGraphqlDocumentFromFile("dataloader_with_different_alias_for_same_field");
    json response = check graphqlClient->execute(document);
    json expectedPayload = check getJsonContentFromFile("dataloader_with_different_alias_for_same_field");
    assertJsonValuesWithOrder(response, expectedPayload);
    lock {
        test:assertEquals(databaseHitForAuthorField, 1, "Database hit for author field is not 1");
        databaseHitForAuthorField = 0;
    }
    lock {
        test:assertEquals(databaseHitForBookField, 1, "Database hit for book field is not 1");
        databaseHitForBookField = 0;
    }
}

@test:Config {
    groups: ["dataloader", "subscription"]
}
isolated function testDataLoaderWithSubscription() returns error? {
    string document = check getGraphqlDocumentFromFile("dataloader_with_subscription");
    string url = "ws://localhost:9090/dataloader";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check initiateGraphqlWsConnection(wsClient);
    check sendSubscriptionMessage(wsClient, document, "1");
    json[] authorSequence = [
        {name: "Author 1", books: [{id: 1, title: "Book 1"}, {id: 2, title: "Book 2"}, {id: 3, title: "Book 3"}]},
        {name: "Author 2", books: [{id: 4, title: "Book 4"}, {id: 5, title: "Book 5"}]},
        {name: "Author 3", books: [{id: 6, title: "Book 6"}, {id: 7, title: "Book 7"}]},
        {name: "Author 4", books: [{id: 8, title: "Book 8"}]},
        {name: "Author 5", books: [{id: 9, title: "Book 9"}]}
    ];

    foreach int i in 0 ..< 5 {
        json expectedMsgPayload = {data: {authors: authorSequence[i]}};
        check validateNextMessage(wsClient, expectedMsgPayload, id = "1");
    }
    lock {
        test:assertEquals(databaseHitForBookField, 5, "Database hit for book field is not 5");
        databaseHitForBookField = 0;
    }
}

@test:Config {
    groups: ["dataloader", "mutation"],
    dependsOn: [testDataLoaderWithQuery, testDataLoaderWithSubscription]
}
isolated function testDataLoaderWithMutation() returns error? {
    string url = "localhost:9090/dataloader";
    graphql:Client graphqlClient = check new (url);
    string document = check getGraphqlDocumentFromFile("dataloader_with_mutation");
    json response = check graphqlClient->execute(document);
    json expectedPayload = check getJsonContentFromFile("dataloader_with_mutation");
    assertJsonValuesWithOrder(response, expectedPayload);
    lock {
        test:assertEquals(databaseHitForUpdateAuthorNameField, 1, "Database hit for updateAuthorName field is not 1");
        databaseHitForUpdateAuthorNameField = 0;
    }
    lock {
        test:assertEquals(databaseHitForBookField, 1, "Database hit for book field is not 1");
        databaseHitForBookField = 0;
    }
}

@test:Config {
    groups: ["dataloader", "interceptor"]
}
isolated function testDataLoaderWithInterceptors() returns error? {
    string url = "localhost:9090/dataloader_with_interceptor";
    graphql:Client graphqlClient = check new (url);
    string document = check getGraphqlDocumentFromFile("dataloader_with_interceptor");
    json response = check graphqlClient->execute(document);
    json expectedPayload = check getJsonContentFromFile("dataloader_with_interceptor");
    assertJsonValuesWithOrder(response, expectedPayload);
    lock {
        test:assertEquals(databaseHitForAuthorField, 1, "Database hit for authorField field is not 1");
        databaseHitForAuthorField = 0;
    }
    lock {
        test:assertEquals(databaseHitForBookField, 1, "Database hit for book field is not 1");
        databaseHitForBookField = 0; // TODO: rename these variables to number of dispatch calls for...
    }
}