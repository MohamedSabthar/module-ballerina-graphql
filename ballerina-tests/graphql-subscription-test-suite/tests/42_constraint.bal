import ballerina/graphql_test_common as common;
import ballerina/test;
import ballerina/websocket;

@test:Config {
    groups: ["constraints", "subscriptions"]
}
isolated function testSubscriptionWithConstraints() returns error? {
    string document = check common:getGraphqlDocumentFromFile("constraints");
    string url = "ws://localhost:9091/constraints";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient);
    check common:sendSubscriptionMessage(wsClient, document, operationName = "Sub");
    json expectedMsgPayload = check common:getJsonContentFromFile("constraints_with_subscription");
    check common:validateErrorMessage(wsClient, expectedMsgPayload);
}

@test:Config {
    groups: ["constraints", "subscriptions"]
}
isolated function testMultipleSubscriptionClientsWithConstraints() returns error? {
    string document = check common:getGraphqlDocumentFromFile("constraints");
    string url = "ws://localhost:9091/constraints";
    websocket:ClientConfiguration config = {subProtocols: [GRAPHQL_TRANSPORT_WS]};
    websocket:Client wsClient1 = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient1);
    check common:sendSubscriptionMessage(wsClient1, document, "1", operationName = "Sub");

    websocket:Client wsClient2 = check new (url, config);
    check common:initiateGraphqlWsConnection(wsClient2);
    check common:sendSubscriptionMessage(wsClient2, document, "2", operationName = "Sub");

    json expectedMsgPayload = check common:getJsonContentFromFile("constraints_with_subscription");
    check common:validateErrorMessage(wsClient1, expectedMsgPayload, "1");
    check common:validateErrorMessage(wsClient2, expectedMsgPayload, "2");
}
