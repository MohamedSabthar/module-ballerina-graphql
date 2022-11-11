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

class TreeModifierVisitor {
    *parser:Visitor;

    private map<parser:ArgumentNode> modfiedArgumentNodes;
    private map<parser:FragmentNode> modifiedFragments;
    private parser:DocumentNode? document;
    private map<parser:Node> modifiedNodes;

    isolated function init(map<parser:FragmentNode> modifiedFragments, map<parser:ArgumentNode> modfiedArgumentNodes) {
        self.modfiedArgumentNodes = modfiedArgumentNodes;
        self.modifiedFragments = modifiedFragments;
        self.modifiedNodes = {};
        self.document = ();
    }

    public isolated function visitDocument(parser:DocumentNode documentNode, anydata data = ()) {
        map<parser:OperationNode> operations = {};
        foreach parser:OperationNode operationNode in documentNode.getOperations() {
            operationNode.accept(self);
            parser:OperationNode operation = <parser:OperationNode>self.getModifiedNode(operationNode);
            operations[operation.getName()] = operation;
        }
        self.document = documentNode.modifyWith(operations);
    }

    public isolated function visitOperation(parser:OperationNode operationNode, anydata data = ()) {
            parser:DirectiveNode[] directives = [];
            foreach parser:DirectiveNode directiveNode in operationNode.getDirectives() {
                directiveNode.accept(self);
                parser:DirectiveNode directive = <parser:DirectiveNode>self.getModifiedNode(directiveNode);
                directives.push(directive);
            }
            map<parser:VariableNode> variables = {};
            foreach [string, parser:VariableNode] [key, variableNode] in operationNode.getVaribleDefinitions().entries() {
                variableNode.accept(self);
                variables[key] = <parser:VariableNode>self.getModifiedNode(variableNode);
            }
            parser:SelectionNode[] selections = [];
            foreach parser:SelectionNode selectionNode in operationNode.getSelections() {
                selectionNode.accept(self);
                parser:SelectionNode selection = <parser:SelectionNode>self.getModifiedNode(selectionNode);
                selections.push(selection);
            }
            string hashCode = parser:getHashCode(operationNode);
            self.modifiedNodes[hashCode] = operationNode.modifyWith(variables, selections, directives);
    }

    public isolated function visitField(parser:FieldNode fieldNode, anydata data = ()) {
        parser:ArgumentNode[] arguments = [];
        foreach parser:ArgumentNode argumentNode in fieldNode.getArguments() {
            argumentNode.accept(self);
            parser:ArgumentNode argument = <parser:ArgumentNode>self.getModifiedNode(argumentNode);
            arguments.push(argument);
        }
        parser:SelectionNode[] selections = [];
        foreach parser:SelectionNode selectionNode in fieldNode.getSelections() {
            selectionNode.accept(self);
            parser:SelectionNode selection = <parser:SelectionNode>self.getModifiedNode(selectionNode);
            selections.push(selection);
        }
        parser:DirectiveNode[] directives = [];
        foreach parser:DirectiveNode directiveNode in fieldNode.getDirectives() {
            directiveNode.accept(self);
            parser:DirectiveNode directive = <parser:DirectiveNode>self.getModifiedNode(directiveNode);
            directives.push(directive);
        }
        string hashCode = parser:getHashCode(fieldNode);
        self.modifiedNodes[hashCode] = fieldNode.modifyWith(arguments, selections, directives);
    }

    public isolated function visitFragment(parser:FragmentNode fragmentNode, anydata data = ()) {
        string fragmentHashCode = parser:getHashCode(fragmentNode);
        parser:FragmentNode fragment = self.modifiedFragments.hasKey(fragmentHashCode) ? self.modifiedFragments.get(fragmentHashCode) : fragmentNode;
        parser:SelectionNode[] selections = [];
        foreach parser:SelectionNode selectionNode in fragment.getSelections() {
            selectionNode.accept(self);
            parser:SelectionNode selection = <parser:SelectionNode>self.getModifiedNode(selectionNode);
            selections.push(selection);
        }
        parser:DirectiveNode[] directives = [];
        foreach parser:DirectiveNode directiveNode in fragment.getDirectives() {
            directiveNode.accept(self);
            parser:DirectiveNode directive = <parser:DirectiveNode>self.getModifiedNode(directiveNode);
            directives.push(directive);
        }
        self.modifiedNodes[fragmentHashCode] = fragment.replaceWith(selections, directives);
    }

    // TODO: Check invalid argument type for valid argument name
    public isolated function visitArgument(parser:ArgumentNode argumentNode, anydata data = ()) {
        string hashCode = parser:getHashCode(argumentNode);
        parser:ArgumentNode argument = self.modfiedArgumentNodes.hasKey(hashCode) ? self.modfiedArgumentNodes.get(hashCode) : argumentNode;
        self.modifiedNodes[hashCode] = argument;
    }

    public isolated function visitDirective(parser:DirectiveNode directiveNode, anydata data = ()) {
        parser:ArgumentNode[] arguments = [];
        foreach parser:ArgumentNode argumentNode in directiveNode.getArguments() {
            argumentNode.accept(self);
            parser:ArgumentNode argument = <parser:ArgumentNode>self.getModifiedNode(argumentNode);
            arguments.push(argument);
        }
        string hashCode = parser:getHashCode(directiveNode);
        self.modifiedNodes[hashCode] = directiveNode.modifyWith(arguments);
    }

    public isolated function visitVariable(parser:VariableNode variableNode, anydata data = ()) {}

    private isolated function getModifiedNode(parser:Node node) returns parser:Node {
        string hashCode = parser:getHashCode(node);
        return self.modifiedNodes.hasKey(hashCode) ? self.modifiedNodes.get(hashCode) : node;
    }

    public isolated function getDocumentNode() returns parser:DocumentNode {
        return <parser:DocumentNode>self.document;
    }

}
