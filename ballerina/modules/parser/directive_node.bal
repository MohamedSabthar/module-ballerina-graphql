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

public isolated class DirectiveNode {
    *NamedNode;

    private string name;
    private Location location;
    private ArgumentNode[] argumentNodes;
    private DirectiveLocation directiveLocation;

    public isolated function init(string name, Location location, DirectiveLocation directiveLocation) {
        self.name = name;
        self.location = location.clone();
        self.argumentNodes = [];
        self.directiveLocation = directiveLocation;
    }

    public isolated function accept(Visitor visitor, anydata data = ()) {
        visitor.visitDirective(self, data);
    }

    public isolated function getName() returns string {
        lock {
            return self.name;
        }
    }

    public isolated function getLocation() returns Location {
        lock {
            return self.location.cloneReadOnly();
        }
    }

    public isolated function getArguments() returns ArgumentNode[] {
        ArgumentNode[] argumentNodes = [];
        lock {
            foreach int i in 0 ..< self.argumentNodes.length() {
                argumentNodes[i] = self.argumentNodes[i];
            }
        }
        return argumentNodes;
    }

    public isolated function addArgument(ArgumentNode arg) {
        lock {
            self.argumentNodes.push(arg);
        }
    }

    public isolated function getDirectiveLocation() returns DirectiveLocation {
        lock {
            return self.directiveLocation.cloneReadOnly();
        }
    }
}
