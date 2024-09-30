// Copyright (c) 2024 WSO2 LLC. (http://www.wso2.com).
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
import ballerina/http;

listener graphql:Listener subscriptionListener = new (9099);
listener http:Listener http2Listener = new http:Listener(9190);
listener graphql:Listener http2BasedListener = new (http2Listener);
listener http:Listener http1Listener = new http:Listener(9191, httpVersion = http:HTTP_1_0);
listener graphql:Listener http1BasedListener = new (http1Listener);
listener graphql:Listener serviceTypeListener = new (9092);
listener graphql:Listener basicListener = new (9091);

listener http:Listener httpListener = new (9090, httpVersion = http:HTTP_1_1);
listener graphql:Listener wrappedListener = new (httpListener);
