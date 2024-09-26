// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

@test:Config {
    groups: ["service", "schema_generation"],
    dataProvider: dataProviderRecursiveServiceTypes
}
isolated function testRecursiveServiceTypes(string resourceFileName) returns error? {
    string url = "http://localhost:9092/snowtooth";
    string document = check common:getGraphqlDocumentFromFile(resourceFileName);
    json actualPayload = check common:getJsonPayloadFromService(url, document);
    json expectedPayload = check common:getJsonContentFromFile(resourceFileName);
    common:assertJsonValuesWithOrder(actualPayload, expectedPayload);
}

function dataProviderRecursiveServiceTypes() returns string[][] {
    return [
        ["returning_recursive_service_type"],
        ["request_invalid_field_from_service_objects"],
        ["returning_union_of_service_objects"],
        ["graphql_playground_introspection_query"]
    ];
}
