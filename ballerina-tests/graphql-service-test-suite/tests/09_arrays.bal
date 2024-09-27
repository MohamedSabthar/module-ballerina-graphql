// Copyright (c) 2020, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
    groups: ["arrays"],
    dataProvider: dataProviderArrays
}
isolated function testArrays(string url, string resourceFileName) returns error? {
    string document = check common:getGraphqlDocumentFromFile(resourceFileName);
    json actualPayload = check common:getJsonPayloadFromService(url, document);
    json expectedPayload = check common:getJsonContentFromFile(resourceFileName);
    common:assertJsonValuesWithOrder(actualPayload, expectedPayload);
}

function dataProviderArrays() returns string[][] {
    string url1 = "http://localhost:9095/special_types";
    string url2 = "http://localhost:9092/service_objects";

    return [
        [url1, "scalar_arrays"],
        [url1, "scalar_arrays_with_errors"],
        [url1, "scalar_nullable_arrays_with_errors"],
        [url2, "resource_returning_service_object_array"],
        [url2, "resource_returning_optional_service_object_arrays"],
        [url2, "optional_arrays_with_invalid_query"],
        [url2, "service_object_array_with_fragment_returning_error"],
        [url1, "arrays_with_errors_in_record_field"]
    ];
}

@test:Config {
    groups: ["array", "service"]
}
isolated function testServiceObjectArrayWithInvalidResponseOrder() returns error? {
    string graphqlUrl = "http://localhost:9092/service_objects";
    string document = check common:getGraphqlDocumentFromFile("service_object_array_with_invalid_response_order");
    json result = check common:getJsonPayloadFromService(graphqlUrl, document);
    json expectedPayload = check common:getJsonContentFromFile("service_object_array_with_invalid_response_order");
    test:assertEquals(result, expectedPayload);
    string actualPayloadString = result.toString();
    string expectedPayloadString = expectedPayload.toString();
    test:assertNotEquals(actualPayloadString, expectedPayloadString);
}
