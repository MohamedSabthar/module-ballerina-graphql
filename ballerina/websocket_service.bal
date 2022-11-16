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

import ballerina/lang.value;
import ballerina/websocket;
import graphql.parser;

isolated service class WsService {
    *websocket:Service;

    private final Engine engine;
    private final readonly & __Schema schema;
    private final Context context;
    private map<SubscriptionHandler> activeConnections;
    private final readonly & map<string> customHeaders;
    private boolean initiatedConnection;

    isolated function init(Engine engine, __Schema & readonly schema, map<string> & readonly customHeaders,
                           Context context) {
        self.engine = engine;
        self.schema = schema;
        self.context = context;
        self.customHeaders = customHeaders;
        self.activeConnections = {};
        self.initiatedConnection = false;
    }

    isolated remote function onIdleTimeout(websocket:Caller caller) returns websocket:Error? {
        lock {
            if !self.initiatedConnection {
                closeConnection(caller, 4408, "Connection initialisation timeout");
            }
        }
    }

    isolated remote function onTextMessage(websocket:Caller caller, string text) returns websocket:Error? {
        error? validatedSubProtocol = validateSubProtocol(caller, self.customHeaders);
        if validatedSubProtocol is error {
            closeConnection(caller, 4406, "Subprotocol not acceptable");
            return;
        }
        json|error wsText = value:fromJsonString(text);
        if wsText is error {
            json payload = {errors: [{message: "Invalid format in WebSocket payload: " + wsText.message()}]};
            check sendWebSocketResponse(caller, self.customHeaders, WS_ERROR, payload);
            closeConnection(caller);
            return;
        }

        WSPayload|json|error wsPayload = self.customHeaders != {}
                                        ? wsText.cloneWithType(WSPayload) : value:fromJsonString(text);
        if wsPayload is error {
            json payload = {errors: [{message: "Invalid format in WebSocket payload: " + wsPayload.message()}]};
            check sendWebSocketResponse(caller, self.customHeaders, WS_ERROR, payload);
            closeConnection(caller);
            return;
        }
        if !self.customHeaders.hasKey(WS_SUB_PROTOCOL) {
            return self.handleSubscriptionRequest(caller, wsPayload);
        }
        if wsPayload !is WSPayload {
            return;
        }

        match wsPayload.'type {
            WS_INIT => {
                lock {
                    if self.initiatedConnection {
                        closeConnection(caller, 4429, "Too many initialisation requests");
                        return;
                    }
                    check caller->writeMessage({"type": WS_ACK});
                    self.initiatedConnection = true;
                }
            }
            WS_SUBSCRIBE|WS_START => {
                string? connectionId = wsPayload.id;
                if connectionId is () {
                    return self.handleIdNotPresentInPayload(caller);
                }
                SubscriptionHandler handler = new(connectionId);
                lock {
                    if !self.initiatedConnection {
                        closeConnection(caller, 4401, "Unauthorized");
                        return;
                    }
                    if self.activeConnections.hasKey(connectionId) {
                        closeConnection(caller, 4409, string `Subscriber for ${connectionId} already exists`);
                        return;
                    }
                    self.activeConnections[connectionId] = handler;
                }
                return self.handleSubscriptionRequest(caller, wsPayload, handler);
            }
            WS_STOP|WS_COMPLETE => {
                string? connectionId = wsPayload.id;
                if connectionId is () {
                    return self.handleIdNotPresentInPayload(caller);
                }
                lock {
                    if !self.activeConnections.hasKey(connectionId) {
                        return;
                    }
                    SubscriptionHandler handler = self.activeConnections.remove(connectionId);
                    handler.setUnsubscribed();
                }
            }
            WS_PING => {
                check caller->writeMessage({"type": WS_PONG});
            }
        }
    }

    isolated function handleSubscriptionRequest(websocket:Caller caller, WSPayload|json wsPayload, 
                                                SubscriptionHandler? handler = ()) returns websocket:Error? {
        string? connectionId = handler is () ? () : handler.getId();
        parser:OperationNode|json node = validateSubscriptionPayload(wsPayload, self.engine);
        if node is parser:OperationNode {
            check executeOperation(self.engine, self.context, self.schema, self.customHeaders, caller, node, handler);
        } else {
            check sendWebSocketResponse(caller, self.customHeaders, WS_ERROR, node, connectionId);
            if !self.customHeaders.hasKey(WS_SUB_PROTOCOL) {
                closeConnection(caller);
            }
        }
    }

    isolated function handleError(websocket:Caller caller, error err) returns websocket:Error? {
        json payload = {errors: [{message: "Invalid format in WebSocket payload: " + err.message()}]};
        check sendWebSocketResponse(caller, self.customHeaders, WS_ERROR, payload);
        closeConnection(caller);
    }

    isolated function handleIdNotPresentInPayload(websocket:Caller caller) {
        closeConnection(caller, 1002, string `Request does not contain the id field`);
    }
}
