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

import ballerina/graphql;

@graphql:InterceptorConfig {
    global: false
}
readonly service class StringInterceptor1 {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata|error {
        var result = context.resolve('field);
        if result is string {
            return string `Tom ${result}`;
        }
        return result;
    }
}

readonly service class StringInterceptor2 {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata|error {
        var result = context.resolve('field);
        if result is string && 'field.getAlias().equalsIgnoreCaseAscii("enemy") {
            return string `Marvolo ${result}`;
        }
        return result;
    }
}

readonly service class StringInterceptor3 {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata|error {
        var result = context.resolve('field);
        if result is string {
            return string `Riddle - ${result}`;
        }
        return result;
    }
}

readonly service class Counter {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata|error {
        var result = context.resolve('field);
        if result is int {
            return result + 1;
        }
        return result;
    }
}

readonly service class NullReturn1 {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata|error {
        if 'field.getName() == "name" {
            return;
        }
        return context.resolve('field);
    }
}

readonly service class Street {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata|error {
        _ = context.resolve('field);
        return "Street 3";
    }
}

readonly service class City {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata|error {
        _ = context.resolve('field);
        return "New York";
    }
}

