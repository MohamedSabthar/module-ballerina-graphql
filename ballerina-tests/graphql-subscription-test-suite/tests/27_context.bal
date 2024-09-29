import ballerina/graphql_test_common as common;
import ballerina/test;
import ballerina/websocket;

@test:Config {
    groups: ["context",  "subscriptions"]
}
isolated function testContextWithSubscriptions() returns error? {
    string url = "ws://localhost:9092/context";
    string document = string `subscription { messages }`;
    websocket:ClientConfiguration configs = {
        customHeaders: {
            "scope": "admin"
        },
        subProtocols: [GRAPHQL_TRANSPORT_WS]
    };
    websocket:Client wsClient = check new (url, configs);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendSubscriptionMessage(wsClient, document);
    foreach int i in 1 ..< 4 {
        json expectedMsgPayload = {data: {messages: i}};
        check common:validateNextMessage(wsClient, expectedMsgPayload);
    }
}

@test:Config {
    groups: ["context", "subscriptions"]
}
isolated function testContextWithInvalidScopeInSubscriptions() returns error? {
    string url = "ws://localhost:9092/context";
    string document = string `subscription { messages }`;
    websocket:ClientConfiguration configs = {
        customHeaders: {
            "scope": "user"
        },
        subProtocols: [GRAPHQL_TRANSPORT_WS]
    };
    websocket:Client wsClient = check new (url, configs);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendSubscriptionMessage(wsClient, document);
    json expectedErrorPayload = [
        {
            message: "You don't have permission to retrieve data",
            locations: [{line: 1, column: 16}],
            path: ["messages"]
        }
    ];
    check common:validateErrorMessage(wsClient, expectedErrorPayload);
}
