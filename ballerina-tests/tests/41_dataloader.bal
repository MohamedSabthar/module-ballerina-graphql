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
    groups: ["dataloader", "mutation"],
    dependsOn: [testDataLoaderWithQuery]
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
    groups: ["dataloader", "mutation", "interceptor"]
}
isolated function testDataLoaderWithInterceptor() returns error? {
    // string url = "localhost:9090/dataloader";
    // graphql:Client graphqlClient = check new (url);
    // string document = check getGraphqlDocumentFromFile("dataloader_with_mutation");
    // json response = check graphqlClient->execute(document);
    // json expectedPayload = check getJsonContentFromFile("dataloader_with_mutation");
    // assertJsonValuesWithOrder(response, expectedPayload);
    // lock {
    //     test:assertEquals(databaseHitForUpdateAuthorNameField, 1, "Database hit for updateAuthorName field is not 1");
    //     databaseHitForUpdateAuthorNameField = 0;
    // }
    // lock {
    //     test:assertEquals(databaseHitForBookField, 1, "Database hit for book field is not 1");
    //     databaseHitForBookField = 0;
    // }
}