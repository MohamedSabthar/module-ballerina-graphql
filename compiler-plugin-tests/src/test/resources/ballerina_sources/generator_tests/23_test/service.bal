// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
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

@graphql:ServiceConfig {
    graphiql: {
        enabled: true
    },
    cors: {allowOrigins: ["*"]},
    isSubgraph: true
}
service on new graphql:Listener(4001) {
    resource function get me() returns User {
        return new;
    }

    resource function get A() returns A {
        return new;
    }

    resource function get B() returns B {
        return new;
    }

    resource function get C() returns C {
        return new;
    }

    resource function get D() returns D {
        return new;
    }
}

@graphql:Entity {
    key: "email",
    resolveReference: isolated function(graphql:Representation representation) returns User|error? {
        return new;
    }
}
distinct service class User {
    resource function get email() returns string {
        return "sabthar@wso2.com";
    }

    resource function get name() returns string {
        return "sabthar mahroof";
    }
}

@graphql:Entity {
    key: "email",
    resolveReference: isolated function(graphql:Representation representation) returns A|error? {
        return new;
    }
}
distinct service class A {
    resource function get email() returns string {
        return "sabthar@wso2.com";
    }

    resource function get name() returns string {
        return "sabthar mahroof";
    }
}

@graphql:Entity {
    key: "email",
    resolveReference: isolated function(graphql:Representation representation) returns B|error? {
        return new;
    }
}
distinct service class B {
    resource function get email() returns string {
        return "sabthar@wso2.com";
    }

    resource function get name() returns string {
        return "sabthar mahroof";
    }
}

@graphql:Entity {
    key: "email",
    resolveReference: isolated function(graphql:Representation representation) returns C|error? {
        return new;
    }
}
distinct service class C {
    resource function get email() returns string {
        return "sabthar@wso2.com";
    }

    resource function get name() returns string {
        return "sabthar mahroof";
    }
}

@graphql:Entity {
    key: "email",
    resolveReference: isolated function(graphql:Representation representation) returns D|error? {
        return new;
    }
}
distinct service class D {
    resource function get email() returns string {
        return "sabthar@wso2.com";
    }

    resource function get name() returns string {
        return "sabthar mahroof";
    }
}
