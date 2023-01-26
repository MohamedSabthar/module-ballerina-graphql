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

import ballerina/test;
import ballerina/graphql;
import ballerina/io;

@test:Config {
    groups: ["fed"]
}
isolated function testFed() returns error? {
    string document = string `query { _entities(representations: [1, "sasa", {
  __typename: "Userf",
  email: "alex@moonhighway.com"
  }, {
  __typename: "Userf",
  email: "alex@moonhighway.com"
  }, ["sa","b"]]) { ... on Userf { name } } }`;
    string url = "localhost:4040";
    map<json> variables = {};
    graphql:Client graphqlClient = check new (url);
    json response = check graphqlClient->execute(document, variables);
    io:println(response);
}
