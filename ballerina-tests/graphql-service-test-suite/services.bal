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

import ballerina/graphql as gql;

listener gql:Listener graphqlListener = new (9098);

service /interfaces on graphqlListener {
    isolated resource function get character(int id) returns Character {
        return new Human("Luke Skywalker", 1);
    }

    isolated resource function get characters() returns Character[] {
        return [new Human("Luke Skywalker", 1), new Droid("R2D2", 1977)];
    }

    isolated resource function get ships() returns Ship[] {
        return [new Starship("E1", "Organo"), new Starship("E2", "Solo")];
    }
}

service /interfaces_implementing_interface on graphqlListener {
    resource function get animal(int id) returns Animalia? {
        return id <= animals.length() && id > 0 ? animals[id - 1] : ();
    }
}
