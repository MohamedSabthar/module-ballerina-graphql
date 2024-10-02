// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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


import ballerina/graphql_test_common as common;
import ballerina/test;
import ballerina/websocket;
import ballerina/io;

@test:Config {
    groups: ["introspection", "typename", "subscriptions"]
}
isolated function testSubscriptionWithIntrospectionInFields() returns error? {
    io:println("start testSubscriptionWithIntrospectionInFields");
    string document = string `subscription { students { __typename } }`;
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendSubscriptionMessage(wsClient, document);

    json expectedMsgPayload = {data: {students: {__typename: "StudentService"}}};
    check common:validateNextMessage(wsClient, expectedMsgPayload);
    io:println("end testSubscriptionWithIntrospectionInFields");
}

@test:Config {
    groups: ["subscriptions"]
}
isolated function testInvalidSubscription() returns error? {
    io:println("start testInvalidSubscription");
    string document = string `subscription { invalidField }`;
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendSubscriptionMessage(wsClient, document);

    json expectedMsgPayload = check common:getJsonContentFromFile("subscription_invalid_field");
    check common:validateErrorMessage(wsClient, expectedMsgPayload);
    io:println("end testInvalidSubscription");
}

@test:Config {
    groups: ["subscriptions"]
}
isolated function testSubscriptionFunctionWithErrors() returns error? {
    io:println("start testSubscriptionFunctionWithErrors");
    string document = string `subscription getNames { values }`;
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendSubscriptionMessage(wsClient, document);

    json expectedErrorPayload = [
        {
            message: "{ballerina/lang.array}IndexOutOfRange",
            locations: [{line: 1, column: 25}],
            path: ["values"]
        }
    ];
    check common:validateErrorMessage(wsClient, expectedErrorPayload);
    io:println("end testSubscriptionFunctionWithErrors");
}

@test:Config {
    groups: ["service", "subscriptions"]
}
isolated function testSubscriptionWithServiceObjects() returns error? {
    io:println("start testSubscriptionWithServiceObjects");
    string document = check common:getGraphqlDocumentFromFile("subscriptions_with_service_objects");
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendSubscriptionMessage(wsClient, document);

    json expectedMsgPayload = {data: {students: {id: 1, name: "Eren Yeager"}}};
    check common:validateNextMessage(wsClient, expectedMsgPayload);
    expectedMsgPayload = {data: {students: {id: 2, name: "Mikasa Ackerman"}}};
    check common:validateNextMessage(wsClient, expectedMsgPayload);
    check common:validateCompleteMessage(wsClient);
    io:println("end testSubscriptionWithServiceObjects");
    
}

@test:Config {
    groups: ["subscriptions"]
}
isolated function testSubscriptionWithMultipleClients() returns error? {
    io:println("start testSubscriptionWithMultipleClients");
    string document = string `subscription { messages }`;
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};

    websocket:Client wsClient1 = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient1);
    check common:sendSubscriptionMessage(wsClient1, document, "1");

    websocket:Client wsClient2 = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient2);
    check common:sendSubscriptionMessage(wsClient2, document, "2");

    foreach int i in 1 ..< 6 {
        json expectedMsgPayload = {data: {messages: i}};
        check common:validateNextMessage(wsClient1, expectedMsgPayload, id = "1");
        check common:validateNextMessage(wsClient2, expectedMsgPayload, id = "2");
    }
    check common:validateCompleteMessage(wsClient1, id = "1");
    check common:validateCompleteMessage(wsClient2, id = "2");
    io:println("end testSubscriptionWithMultipleClients");
}

@test:Config {
    groups: ["subscriptions"]
}
isolated function testConnectionInitMessage() returns error? {
    io:println("start testConnectionInitMessage");
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:sendConnectionInitMessage(wsClient);
    check common:validateConnectionAckMessage(wsClient);
    io:println("end testConnectionInitMessage");
}

@test:Config {
    groups: ["subscriptions"]
}
isolated function testInvalidMultipleConnectionInitMessages() returns error? {
    io:println("start testInvalidMultipleConnectionInitMessages");
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendConnectionInitMessage(wsClient);

    string expectedErrorMsg = "Too many initialisation requests: Status code: 4429";
    common:validateConnectionClousureWithError(wsClient, expectedErrorMsg);
    io:println("end testInvalidMultipleConnectionInitMessages");
}

@test:Config {
    groups: ["subscriptions"]
}
isolated function testUnauthorizedAccess() returns error? {
    io:println("start testUnauthorizedAccess");
    string document = check common:getGraphqlDocumentFromFile("subscriptions_with_service_objects");
    string url = "ws://localhost:9091/subscriptions";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:sendSubscriptionMessage(wsClient, document);

    string expectedErrorMsg = "Unauthorized: Status code: 4401";
    common:validateConnectionClousureWithError(wsClient, expectedErrorMsg);
    io:println("end testUnauthorizedAccess");
}
