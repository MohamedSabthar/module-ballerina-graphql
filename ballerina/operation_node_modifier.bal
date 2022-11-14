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

import graphql.parser;

class OperationNodeModifierVisitor {
    *parser:Visitor;

    private map<parser:SelectionNode> modifiedSelections;
    private parser:OperationNode? operation;
    private map<parser:Node> modifiedNodes;
    private map<parser:Node> removedNodes;

    isolated function init(map<parser:SelectionNode> modifiedSelections, map<parser:Node> removedNodes) {
        self.modifiedSelections = modifiedSelections;
        self.modifiedNodes = {};
        self.operation = ();
        self.removedNodes = removedNodes;
    }

    public isolated function visitDocument(parser:DocumentNode documentNode, anydata data = ()) {
    }

    public isolated function visitOperation(parser:OperationNode operationNode, anydata data = ()) {
            // parser:DirectiveNode[] directives = [];
            // foreach parser:DirectiveNode directiveNode in operationNode.getDirectives() {
            //     directiveNode.accept(self);
            //     parser:DirectiveNode directive = <parser:DirectiveNode>self.getModifiedNode(directiveNode);
            //     directives.push(directive);
            // }
            // map<parser:VariableNode> variables = {};
            // foreach [string, parser:VariableNode] [key, variableNode] in operationNode.getVaribleDefinitions().entries() {
            //     variableNode.accept(self);
            //     variables[key] = <parser:VariableNode>self.getModifiedNode(variableNode);
            // }
            parser:SelectionNode[] selections = [];
            foreach parser:SelectionNode selectionNode in operationNode.getSelections() {
                string hashCode = parser:getHashCode(selectionNode);
                if self.removedNodes.hasKey(hashCode) {
                    continue;
                }
                selectionNode.accept(self);
                parser:SelectionNode selection = <parser:SelectionNode>self.getModifiedNode(selectionNode);
                selections.push(selection);
            }
            // string hashCode = parser:getHashCode(operationNode);
            self.operation = operationNode.modifyWith(operationNode.getVaribleDefinitions(), selections, operationNode.getDirectives());

    }

    public isolated function visitField(parser:FieldNode fieldNode, anydata data = ()) {
        string fieldHashCode = parser:getHashCode(fieldNode);
        parser:FieldNode 'field = self.modifiedSelections.hasKey(fieldHashCode) ? <parser:FieldNode>self.modifiedSelections.get(fieldHashCode) : fieldNode;
        // parser:ArgumentNode[] arguments = [];
        // foreach parser:ArgumentNode argumentNode in 'field.getArguments() {
        //     argumentNode.accept(self);
        //     parser:ArgumentNode argument = <parser:ArgumentNode>self.getModifiedNode(argumentNode);
        //     arguments.push(argument);
        // }
        parser:SelectionNode[] selections = [];
        foreach parser:SelectionNode selectionNode in 'field.getSelections() {
            string hashCode = parser:getHashCode(selectionNode);
            if self.removedNodes.hasKey(hashCode) {
                continue;
            }
            selectionNode.accept(self);
            parser:SelectionNode selection = <parser:SelectionNode>self.getModifiedNode(selectionNode);
            selections.push(selection);
        }
        // parser:DirectiveNode[] directives = [];
        // foreach parser:DirectiveNode directiveNode in 'field.getDirectives() {
        //     directiveNode.accept(self);
        //     parser:DirectiveNode directive = <parser:DirectiveNode>self.getModifiedNode(directiveNode);
        //     directives.push(directive);
        // }
        self.modifiedNodes[fieldHashCode] = 'field.modifyWith('field.getArguments(), selections, 'field.getDirectives());
    }

    public isolated function visitFragment(parser:FragmentNode fragmentNode, anydata data = ()) {
        string fragmentHashCode = parser:getHashCode(fragmentNode);
        parser:FragmentNode fragment = self.modifiedSelections.hasKey(fragmentHashCode) ? <parser:FragmentNode>self.modifiedSelections.get(fragmentHashCode) : fragmentNode;
        parser:SelectionNode[] selections = [];
        foreach parser:SelectionNode selectionNode in fragment.getSelections() {
            string hashCode = parser:getHashCode(selectionNode);
            if self.removedNodes.hasKey(hashCode) {
                continue;
            }
            selectionNode.accept(self);
            parser:SelectionNode selection = <parser:SelectionNode>self.getModifiedNode(selectionNode);
            selections.push(selection);
        }
        // parser:DirectiveNode[] directives = [];
        // foreach parser:DirectiveNode directiveNode in fragment.getDirectives() {
        //     directiveNode.accept(self);
        //     parser:DirectiveNode directive = <parser:DirectiveNode>self.getModifiedNode(directiveNode);
        //     directives.push(directive);
        // }
        self.modifiedNodes[fragmentHashCode] = fragment.replaceWith(selections, fragment.getDirectives());
    }

    // TODO: Check invalid argument type for valid argument name
    public isolated function visitArgument(parser:ArgumentNode argumentNode, anydata data = ()) {
        // string hashCode = parser:getHashCode(argumentNode);
        // parser:ArgumentNode argument = self.modfiedArgumentNodes.hasKey(hashCode) ? self.modfiedArgumentNodes.get(hashCode) : argumentNode;
        // self.modifiedNodes[hashCode] = argument;
    }

    public isolated function visitDirective(parser:DirectiveNode directiveNode, anydata data = ()) {
        // parser:ArgumentNode[] arguments = [];
        // foreach parser:ArgumentNode argumentNode in directiveNode.getArguments() {
        //     argumentNode.accept(self);
        //     parser:ArgumentNode argument = <parser:ArgumentNode>self.getModifiedNode(argumentNode);
        //     arguments.push(argument);
        // }
        // string hashCode = parser:getHashCode(directiveNode);
        // self.modifiedNodes[hashCode] = directiveNode.modifyWith(arguments);
    }

    public isolated function visitVariable(parser:VariableNode variableNode, anydata data = ()) {}

    private isolated function getModifiedNode(parser:Node node) returns parser:Node {
        string hashCode = parser:getHashCode(node);
        return self.modifiedNodes.hasKey(hashCode) ? self.modifiedNodes.get(hashCode) : node;
    }

    public isolated function getOperationNode() returns parser:OperationNode {
        return <parser:OperationNode>self.operation;
    }

}
