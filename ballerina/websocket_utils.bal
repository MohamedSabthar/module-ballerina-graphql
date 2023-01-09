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

import ballerina/log;
import ballerina/websocket;
import graphql.parser;

isolated function executeOperation(Engine engine, Context context, readonly & __Schema schema,
        readonly & map<string> customHeaders, websocket:Caller caller,
        parser:OperationNode node, SubscriptionHandler subscriptionHandler) {
    stream<any, error?>|json sourceStream;
    do {
        SubscriptionHandler handler = subscriptionHandler;
        string connectionId = handler.getId();
        RootFieldVisitor rootFieldVisitor = new (node);
        parser:FieldNode fieldNode = <parser:FieldNode>rootFieldVisitor.getRootFieldNode();
        sourceStream = getSubscriptionResponse(engine, schema, context, fieldNode);
        if sourceStream is stream<any, error?> {
            record {|any value;|}|error? next = sourceStream.next();
            while next !is () {
                if handler.getUnsubscribed() {
                    closeStream(sourceStream);
                    return;
                }
                any|error resultValue = next is error ? next : next.value;
                OutputObject outputObject = engine.getResult(node, context, resultValue);
                if outputObject.hasKey(DATA_FIELD) || outputObject.hasKey(ERRORS_FIELD) {
                    check sendWebSocketResponse(caller, customHeaders, WS_NEXT, outputObject.toJson(), connectionId);
                }
                context.resetErrors(); //Remove previous event's errors before the next one
                next = sourceStream.next();
            }
            check handleStreamCompletion(customHeaders, caller, handler, sourceStream);
        } else {
            check handleStreamCreationError(customHeaders, caller, handler, sourceStream);
        }
    } on fail error err {
        log:printError(err.message(), stackTrace = err.stackTrace());
        if sourceStream is stream<any, error?> {
            closeStream(sourceStream);
        }
    }
}

isolated function handleStreamCompletion(readonly & map<string> customHeaders, websocket:Caller caller,
                                         SubscriptionHandler handler, stream<any, error?> sourceStream)
returns websocket:Error? {
    if handler.getUnsubscribed() {
        closeStream(sourceStream);
        return;
    }
    check sendWebSocketResponse(caller, customHeaders, WS_COMPLETE, (), handler.getId());
    closeStream(sourceStream);
}

isolated function handleStreamCreationError(readonly & map<string> customHeaders, websocket:Caller caller,
                                            SubscriptionHandler handler, json errors) returns websocket:Error? {
    if handler.getUnsubscribed() {
        return;
    }
    string connectionId = handler.getId();
    check sendWebSocketResponse(caller, customHeaders, WS_ERROR, errors, connectionId);
}

isolated function validateSubscriptionPayload(SubscribeMessage data, Engine engine) returns parser:OperationNode|json {
    string document = data.payload.query;
    if document == "" {
        return {errors: [{message: "An empty query is found"}]};
    }
    string? operationName = data.payload?.operationName;
    map<json>? variables = data.payload?.variables;
    parser:OperationNode|OutputObject result = engine.validate(document, operationName, variables);
    if result is parser:OperationNode {
        return result;
    }
    return result.toJson();
}

isolated function getSubscriptionResponse(Engine engine, __Schema schema, Context context,
                                          parser:FieldNode node) returns stream<any, error?>|json {
    any|error result = engine.executeSubscriptionResource(context, engine.getService(), node);
    if result is stream<any, error?> {
        return result;
    }
    string errorMessage = result is error ? result.message() : "Error ocurred in the subscription resolver";
    return {errors: [{message: errorMessage}]};
}

isolated function sendWebSocketResponse(websocket:Caller caller, map<string> & readonly customHeaders, string wsType,
                                        json payload, string id) returns websocket:Error? {
        json jsonResponse = {'type: wsType, id: id, payload: payload};
        return caller->writeMessage(jsonResponse);
}

isolated function closeConnection(websocket:Caller caller, int statusCode = 1000, string reason = "Normal Closure") {
    error? closedConnection = caller->close(statusCode, reason, timeout = 5);
    if closedConnection is error {
        // do nothing
    }
}

isolated function validateSubProtocol(websocket:Caller caller, readonly & map<string> customHeaders) returns error? {
    if !customHeaders.hasKey(WS_SUB_PROTOCOL) {
        return error("Subprotocol header not found");
    }
    string subProtocol = customHeaders.get(WS_SUB_PROTOCOL);
    if  subProtocol != GRAPHQL_TRANSPORT_WS {
        return error(string `Unsupported subprotocol "${subProtocol}" requested by the client`);
    }
    return;
}

isolated function closeStream(stream<any, error?> sourceStream) {
    error? result = sourceStream.close();
    if result is error {
        error err = error("Failed to close stream", result);
        log:printError(err.message(), stackTrace = err.stackTrace());
    }
}
