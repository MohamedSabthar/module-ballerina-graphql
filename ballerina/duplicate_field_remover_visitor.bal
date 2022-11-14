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

import graphql.parser;

class DuplicateFieldRemoverVisitor {
    *parser:Visitor;
    private map<parser:Node> removedNodes;
    private map<parser:SelectionNode> modifiedSelections;

    isolated function init(map<parser:Node> removedNodes, map<parser:SelectionNode> modifiedSelections) {
        self.removedNodes = removedNodes;
        self.modifiedSelections = modifiedSelections;
    }

    public isolated function visitDocument(parser:DocumentNode documentNode, anydata data = ()) {
        foreach parser:OperationNode operationNode in documentNode.getOperations() {
            if self.removedNodes.hasKey(parser:getHashCode(operationNode)) {
                continue;
            }
            operationNode.accept(self);
        }
    }

    public isolated function visitOperation(parser:OperationNode operationNode, anydata data = ()) {
        self.removeDuplicateSelections(operationNode.getSelections());
        foreach parser:SelectionNode selection in operationNode.getSelections() {
            if self.removedNodes.hasKey(parser:getHashCode(selection)) {
                continue;
            }
            selection.accept(self);
        }
    }

    public isolated function visitField(parser:FieldNode fieldNode, anydata data = ()) {
        string hashCode = parser:getHashCode(fieldNode);
        parser:FieldNode 'field = self.modifiedSelections.hasKey(hashCode) ? <parser:FieldNode>self.modifiedSelections.get(hashCode) : fieldNode;
        self.removeDuplicateSelections('field.getSelections());
        foreach parser:SelectionNode selection in 'field.getSelections() {
            if self.removedNodes.hasKey(parser:getHashCode(selection)) {
                continue;
            }
            selection.accept(self);
        }
    }

    public isolated function visitFragment(parser:FragmentNode fragmentNode, anydata data = ()) {
        string hashCode = parser:getHashCode(fragmentNode);
        parser:FragmentNode fragment = self.modifiedSelections.hasKey(hashCode) ? <parser:FragmentNode>self.modifiedSelections.get(hashCode) : fragmentNode;
        self.removeDuplicateSelections(fragment.getSelections());
        foreach parser:SelectionNode selection in fragment.getSelections() {
            if self.removedNodes.hasKey(parser:getHashCode(selection)) {
                continue;
            }
            selection.accept(self);
        }
    }

    public isolated function visitArgument(parser:ArgumentNode argumentNode, anydata data = ()) {}

    // this function modifies the array
    private isolated function removeDuplicateSelections(parser:SelectionNode[] selectionsNodes) {
        parser:SelectionNode[] selections = [...selectionsNodes]; // temp
        map<parser:FieldNode> visitedFields = {};
        map<parser:FragmentNode> visitedFragments = {};
        int i = 0;
        while i < selections.length() {
            string hashCode = parser:getHashCode(selections[i]);
            if self.removedNodes.hasKey(hashCode) {
                i+=1;
                continue;
            }
            parser:SelectionNode selection = self.modifiedSelections.hasKey(hashCode) ? self.modifiedSelections.get(hashCode) : selections[i];
            if selection is parser:FragmentNode {
                if visitedFragments.hasKey(selection.getOnType()) {
                    self.appendDuplicates(selection, visitedFragments.get(selection.getOnType()));
                    // var node = selections.remove(i); // ????????????????
                    self.removedNodes[hashCode] = selection;
                    // i -= 1;
                } else {
                    visitedFragments[selection.getOnType()] = selection;
                }
            } else if selection is parser:FieldNode {
                if visitedFields.hasKey(selection.getAlias()) {
                    self.appendDuplicates(selection, visitedFields.get(selection.getAlias()));
                    // var node = selections.remove(i); // ?????????????????
                    self.removedNodes[hashCode] = selection;
                    // i -= 1;
                } else {
                    visitedFields[selection.getAlias()] = selection;
                }
            } else {
                panic error("Invalid selection node passed.");
            }
            i += 1;
        }
    }

    private isolated function appendDuplicates(parser:SelectionParentNode duplicate, parser:SelectionParentNode original) {
        if duplicate is parser:FieldNode && original is parser:FieldNode {
            string hashCode = parser:getHashCode(original);
            parser:FieldNode modifiedOriginalNode = self.modifiedSelections.hasKey(hashCode) ? <parser:FieldNode>self.modifiedSelections.get(hashCode) : original;
            parser:SelectionNode[] combinedSelections = [...modifiedOriginalNode.getSelections(), ...duplicate.getSelections()];
            parser:FieldNode latestModifiedOriginalNode = modifiedOriginalNode.modifyWithSelections(combinedSelections);
            self.modifiedSelections[hashCode] = latestModifiedOriginalNode;
        }
        if duplicate is parser:FragmentNode && original is parser:FragmentNode {
            string hashCode = parser:getHashCode(original);
            parser:FragmentNode modifiedOriginalNode = self.modifiedSelections.hasKey(hashCode) ? <parser:FragmentNode>self.modifiedSelections.get(hashCode) : original;
            parser:SelectionNode[] combinedSelections = [...modifiedOriginalNode.getSelections(), ...duplicate.getSelections()];
            parser:FragmentNode latestModifiedOriginalNode = modifiedOriginalNode.modifyWithSelections(combinedSelections);
            self.modifiedSelections[hashCode] = latestModifiedOriginalNode;
        }
        // foreach parser:SelectionNode selection in duplicate.getSelections() {
        //     // original.addSelection(selection); ?????????????????
        // }
    }

    public isolated function visitDirective(parser:DirectiveNode directiveNode, anydata data = ()) {}

    public isolated function visitVariable(parser:VariableNode variableNode, anydata data = ()) {}
}
