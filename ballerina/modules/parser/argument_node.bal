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

public readonly class ArgumentNode {
    *NamedNode;

    private string name;
    private Location location;
    private ArgumentValue|ArgumentValue[] value;
    private Location valueLocation;
    private ArgumentType kind;
    private string? variableName;
    private anydata variableValue;
    private boolean variableDefinition;
    private boolean containsInvalidValue;

    public isolated function init(string name, Location location, ArgumentType kind,
                                  boolean isVarDef = false, Location? valueLocation = (),
                                  ArgumentValue|ArgumentValue[] value = (), string? variableName = (),
                                  boolean containsInvalidValue = false, anydata variableValue=()) {
        self.name = name;
        self.location = location.cloneReadOnly();
        self.value = value.cloneReadOnly();
        self.valueLocation = valueLocation is () ? location.cloneReadOnly() : valueLocation.cloneReadOnly();
        self.kind = kind;
        self.variableDefinition = isVarDef;
        self.variableName = variableName;
        self.variableValue = variableValue;
        self.containsInvalidValue = containsInvalidValue;
    }

    public isolated function accept(Visitor visitor, anydata data = ()) {
        visitor.visitArgument(self, data);
    }

    public isolated function getName() returns string {
        return self.name;
    }

    public isolated function getLocation() returns Location {
        return self.location;
    }

    public isolated function getKind() returns ArgumentType {
        return self.kind;
    }

    // public isolated function setKind(ArgumentType kind) {
    //     self.kind = kind;
    // }

    // public isolated function addVariableName(string name) {
    //     self.variableName = name;
    // }

    public isolated function getVariableName() returns string? {
        return self.variableName;
    }

    // public isolated function setValue(ArgumentValue|ArgumentValue[] value) {
    //     self.value = value;
    // }

    // public isolated function setValueLocation(Location location) {
    //     self.valueLocation = location;
    // }

    public isolated function getValue() returns ArgumentValue|ArgumentValue[] {
        return self.value;
    }

    public isolated function getValueLocation() returns Location {
        return self.valueLocation;
    }

    // public isolated function setVariableDefinition(boolean value) {
    //     self.variableDefinition = value;
    // }

    public isolated function isVariableDefinition() returns boolean {
        return self.variableDefinition;
    }

    // public isolated function setVariableValue(anydata inputValue) {
    //     self.variableValue = inputValue;
    // }

    public isolated function getVariableValue() returns anydata {
        return self.variableValue;
    }

    // public isolated function setInvalidVariableValue() {
    //     self.containsInvalidValue = true;
    // }

    public isolated function hasInvalidVariableValue() returns boolean {
        return self.containsInvalidValue;
    }

    public isolated function modifyWith(
            ArgumentType? kind = (),
            string? variableName = (),
            ArgumentValue|ArgumentValue[] value = (),
            Location? valueLocation = (),
            boolean? isVarDef = (),
            anydata variableValue = (),
            boolean? containsInvalidValue = ()) returns ArgumentNode {

        string? modfiedVariableName = variableName is () ? self.variableName : variableName;
        ArgumentType modfiedKind = kind is () ? self.kind : kind;
        boolean variableDefinition = isVarDef is () ? self.variableDefinition : isVarDef;
        Location? modifeidValueLocation = valueLocation is () ? self.valueLocation : valueLocation;
        ArgumentValue|ArgumentValue[] modifedValue = value is () ? self.value : value;
        boolean modifiedContainsInvalidValue = containsInvalidValue is () ? self.containsInvalidValue : containsInvalidValue;
        anydata modifiedVariableValue = variableValue is () ? self.variableValue : variableValue;

        return new (self.name, self.location, modfiedKind, variableDefinition, modifeidValueLocation,
                    modifedValue, modfiedVariableName, modifiedContainsInvalidValue, modifiedVariableValue);
    }

    public isolated function modifyWithValue(ArgumentValue|ArgumentValue[] value) returns ArgumentNode {
        return new (self.name, self.location, self.kind, self.variableDefinition, self.valueLocation,
                    value, self.variableName, self.containsInvalidValue, self.variableValue);
    }
}
