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

public class FragmentNode {
    *SelectionNode;

    private string name;
    private Location location;
    private Location? spreadLocation;
    private string onType;
    private boolean inlineFragment;
    private SelectionNode[] selections;
    private DirectiveNode[] directives;
    private boolean unknown;

    public isolated function init(string name, Location location, boolean inlineFragment, Location? spreadLocation = (),
                                  string onType = "") {
        self.name = name;
        self.location = location;
        self.spreadLocation = spreadLocation;
        self.onType = onType;
        self.inlineFragment = inlineFragment;
        self.selections = [];
        self.directives = [];
        self.unknown = false;
    }

    public isolated function accept(Visitor visitor, anydata data = ()) {
        visitor.visitFragment(self, data);
    }

    public isolated function getName() returns string {
        return self.name;
    }

    public isolated function getLocation() returns Location {
        return self.location;
    }

    public isolated function getOnType() returns string {
        return self.onType;
    }

    public isolated function addSelection(SelectionNode selection) {
        self.selections.push(selection);
    }

    public isolated function getSelections() returns SelectionNode[] {
        return self.selections;
    }

    public isolated function isInlineFragment() returns boolean {
        return self.inlineFragment;
    }

    public isolated function getSpreadLocation() returns Location? {
        return self.spreadLocation;
    }

    public isolated function setLocation(Location location) {
        self.location = location;
    }

    public isolated function setOnType(string onType) {
        self.onType = onType;
    }

    public isolated function addDirective(DirectiveNode directive) {
        self.directives.push(directive);
    }

    public isolated function getDirectives() returns DirectiveNode[] {
        return self.directives;
    }

    public isolated function setToUnknown() {
        self.unknown = true;
    }

    public isolated function isUnknown() returns boolean {
        return self.unknown;
    }
}
