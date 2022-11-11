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

public class Parser {
    private Lexer lexer;
    // private DocumentNode document;
    private map<FragmentNode> fragments;
    private map<OperationNode> operations;
    private ErrorDetail[] errors;
    private boolean isFirstAnonymousOperationErrorPushed;

    public isolated function init(string text) {
        self.lexer = new (text);
        self.fragments = {};
        self.operations = {};
        self.errors = [];
        self.isFirstAnonymousOperationErrorPushed = false;
        // self.document = new;
    }

    public isolated function parse() returns DocumentNode|Error {
        check self.populateDocument();
        DocumentNode document = new(self.operations, self.fragments);
        return document;
    }

    isolated function populateDocument() returns Error? {
        Token token = check self.peekNextNonSeparatorToken();

        while token.kind != T_EOF {
            check self.parseRootOperation(token);
            token = check self.peekNextNonSeparatorToken();
        }
    }

    isolated function parseRootOperation(Token token) returns Error? {
        if token.kind == T_OPEN_PARENTHESES || token.kind == T_OPEN_BRACE || token.kind == T_AT {
            return self.parseAnonymousOperation();
        } else if token.kind == T_IDENTIFIER {
            Scalar value = token.value;
            if value is RootOperationType {
                return self.parseOperationWithType(value);
            } else if value == FRAGMENT {
                return self.parseFragment();
            }
        }
        return getUnexpectedTokenError(token);
    }

    isolated function parseAnonymousOperation() returns Error? {
        Token token = check self.peekNextNonSeparatorToken();
        OperationNode operation = check self.createOperationNode(ANONYMOUS_OPERATION, OPERATION_QUERY, token.location);
        self.addOperationToMap(operation);
    }

    isolated function parseOperationWithType(RootOperationType operationType) returns Error? {
        Token token = check self.readNextNonSeparatorToken();
        Location location = token.location.clone();
        token = check self.peekNextNonSeparatorToken();
        string operationName = check getOperationNameFromToken(self);
        token = check self.peekNextNonSeparatorToken();
        TokenType tokenType = token.kind;
        if tokenType == T_OPEN_PARENTHESES || tokenType == T_OPEN_BRACE || tokenType == T_AT {
            OperationNode operation = check self.createOperationNode(operationName, operationType, location);
            self.addOperationToMap(operation);
        } else {
            return getExpectedCharError(token, OPEN_BRACE);
        }
    }

    isolated function parseFragment() returns Error? {
        Token token = check self.readNextNonSeparatorToken(); // fragment keyword already validated
        Location location = token.location.clone();

        token = check self.readNextNonSeparatorToken();
        string name = check getIdentifierTokenvalue(token);
        if name == ON {
            return getUnexpectedTokenError(token);
        }

        token = check self.readNextNonSeparatorToken();
        string keyword = check getIdentifierTokenvalue(token);
        if keyword != ON {
            return getExpectedCharError(token, ON);
        }

        token = check self.readNextNonSeparatorToken();
        string onType = check getIdentifierTokenvalue(token);

        DirectiveNode[]  directiveNodes = check self.addDirectivesToSelection(FRAGMENT_DEFINITION);
        token = check self.peekNextNonSeparatorToken();
        if token.kind != T_OPEN_BRACE {
            return getExpectedCharError(token, OPEN_BRACE);
        }
        SelectionNode[] selectionNodes = check self.addSelections(name);
        FragmentNode fragmentNode = new (name, location, false, onType = onType, selections = selectionNodes, directives = directiveNodes);
        self.addFragmentToMap(fragmentNode);
    }

    isolated function createOperationNode(string name, RootOperationType kind, Location location)
    returns OperationNode|Error {
        Token token = check self.peekNextNonSeparatorToken();
        map<VariableNode> variables = {};
        if token.kind == T_OPEN_PARENTHESES {
            variables = check self.addVariableDefinition();
        }
        DirectiveNode[] directiveNodes = check self.addDirectivesToSelection(getLocationFromRootOperationType(kind));
        SelectionNode[] selectionNodes = check self.addSelections(name);
        OperationNode operation = new (name, kind, location, variables = variables, directives = directiveNodes, selections = selectionNodes);
        return operation;
    }

    isolated function addVariableDefinition() returns map<VariableNode>|Error {
        Token token = check self.readNextNonSeparatorToken(); // Read the open parantheses here
        map<VariableNode> variableNodes = {};
        while token.kind != T_CLOSE_PARENTHESES {
            token = check self.readNextNonSeparatorToken();
            if token.kind != T_DOLLAR {
                return getExpectedCharError(token, DOLLAR);
            }
            Location varDefinitionLocation = token.location.clone();
            token = check self.readNextNonSeparatorToken();
            string name = check getIdentifierTokenvalue(token);
            Location varLocation = token.location.clone();
            token = check self.readNextNonSeparatorToken();
            if token.kind != T_COLON {
                return getExpectedCharError(token, COLON);
            }
            token = check self.readNextNonSeparatorToken();
            string varType = check self.getTypeIdentifierTokenValue(token);
            token = check self.peekNextNonSeparatorToken();
            ArgumentNode? value = ();
            if token.kind == T_EQUAL {
                token = check self.readNextNonSeparatorToken(); // consume "=" sign here
                token = check self.peekNextNonSeparatorToken();
                if token.kind == T_OPEN_BRACE {
                    value = check self.getInputObjectTypeArgument(name, varLocation, false);
                } else if token.kind == T_OPEN_BRACKET {
                    value = check self.getListTypeArgument(name, varLocation, false);
                } else {
                    value = check self.getScalarTypeArgument(name, varLocation, false);
                }
                token = check self.peekNextNonSeparatorToken();
            }
            VariableNode variableNode = new (name, varType, varDefinitionLocation, value);
            self.updateVariableDefinitionMap(variableNodes, variableNode); // ---> operationNode.addVariableDefinition(variableNode);
        }
        token = check self.readNextNonSeparatorToken();
        return variableNodes;
    }

    isolated function updateVariableDefinitionMap(map<VariableNode> variables, VariableNode variable) {
        if variables.hasKey(variable.getName()) {
            string message = string `There can be only one variable named "$${variable.getName()}"`;
            Location location = variable.getLocation();
            self.errors.push({message: message, locations: [location]});
        } else {
            variables[variable.getName()] = variable;
        }
    }

    isolated function addSelections(string parentNodeName) returns SelectionNode[]|Error {
        Token token = check self.readNextNonSeparatorToken(); // Read the open brace here
        SelectionNode[] selectionNodes = [];
        while token.kind != T_CLOSE_BRACE {
            token = check self.peekNextNonSeparatorToken();
            if token.kind == T_ELLIPSIS {
                check self.addFragment(parentNodeName, selectionNodes);
            } else {
                FieldNode fieldNode = check self.addSelectionToNode();
                // parentNode.addSelection(fieldNode);
                selectionNodes.push(fieldNode);
            }
            token = check self.peekNextNonSeparatorToken();
        }
        // If it comes to this, token.kind == T_CLOSE_BRACE. We consume it
        token = check self.readNextNonSeparatorToken();
        return selectionNodes;
    }

    isolated function addFragment(string parentNodeName, SelectionNode[] selectionNodes) returns Error? {
        Token token = check self.readNextNonSeparatorToken(); // Consume Ellipsis token
        Location spreadLocation = token.location;
        token = check self.peekNextNonSeparatorToken();
        string keyword = check getIdentifierTokenvalue(token);
        if keyword == ON {
            check self.addInlineFragmentToNode(parentNodeName, spreadLocation, selectionNodes);
        } else {
            check self.addNamedFragmentToNode(spreadLocation, selectionNodes);
        }
    }

    isolated function addSelectionToNode() returns FieldNode|Error {
        Token token = check self.readNextNonSeparatorToken();
        string alias = check getIdentifierTokenvalue(token);
        string name = check self.getNameWhenAliasPresent(alias);
        Location fieldNodeLocation = token.location;
        ArgumentNode[] argumentNodes = check self.addArgumentsToSelection();
        DirectiveNode[] directiveNodes = check self.addDirectivesToSelection(FIELD);
        token = check self.peekNextNonSeparatorToken();
        SelectionNode[] selectionNodes = [];
        if token.kind == T_OPEN_BRACE {
            selectionNodes = check self.addSelections(name);
        }
        FieldNode fieldNode = new (name, fieldNodeLocation, alias, selections = selectionNodes, arguments = argumentNodes, directives = directiveNodes);
        return fieldNode;
    }

    isolated function addNamedFragmentToNode(Location spreadLocation, SelectionNode[] selectionNodes) returns Error? {
        Token token = check self.readNextNonSeparatorToken();
        string fragmentName = check getIdentifierTokenvalue(token);
        DirectiveNode[] directiveNodes = check self.addDirectivesToSelection(FRAGMENT_SPREAD);
        FragmentNode fragmentNode = new (fragmentName, token.location, false, spreadLocation, directives = directiveNodes);
        // parentNode.addSelection(fragmentNode);
        selectionNodes.push(fragmentNode);
    }

    isolated function addInlineFragmentToNode(string parentNodeName, Location spreadLocation, SelectionNode[] selectionNodes)
    returns Error? {
        Token token = check self.readNextNonSeparatorToken(); //Consume on keyword
        token = check self.readNextNonSeparatorToken();
        Location location = token.location;
        string onType = check getIdentifierTokenvalue(token);
        string fragmentName = string `${parentNodeName}_${onType}`;
        DirectiveNode[] directiveNodes = check self.addDirectivesToSelection(INLINE_FRAGMENT);
        token = check self.peekNextNonSeparatorToken();
        if token.kind != T_OPEN_BRACE {
            return getExpectedCharError(token, OPEN_BRACE);
        }
        SelectionNode[] selections = check self.addSelections(fragmentName);
        FragmentNode fragmentNode = new (fragmentName, location, true, spreadLocation, onType, directives = directiveNodes, selections = selections);
        self.addFragmentToMap(fragmentNode);
        // parentNode.addSelection(fragmentNode);
        selectionNodes.push(fragmentNode);
    }

    isolated function addArgumentsToSelection() returns ArgumentNode[]|Error {
        Token token = check self.peekNextNonSeparatorToken();
        ArgumentNode[] argumentNodes = [];
        if token.kind != T_OPEN_PARENTHESES {
            return argumentNodes;
        }
        token = check self.readNextNonSeparatorToken();
        while token.kind != T_CLOSE_PARENTHESES {
            token = check self.readNextNonSeparatorToken();
            string name = check getIdentifierTokenvalue(token);
            Location location = token.location.clone();
            token = check self.readNextNonSeparatorToken();
            if token.kind != T_COLON {
                return getExpectedCharError(token, COLON);
            }
            token = check self.peekNextNonSeparatorToken();
            if token.kind == T_OPEN_BRACE {
                ArgumentNode argumentNode = check self.getInputObjectTypeArgument(name, location);
                argumentNodes.push(argumentNode);
                // fieldNode.addArgument(argumentNode);
            } else if token.kind == T_OPEN_BRACKET {
                ArgumentNode argumentNode = check self.getListTypeArgument(name, location);
                argumentNodes.push(argumentNode);
                // fieldNode.addArgument(argumentNode);
            } else {
                ArgumentNode argument = check self.getScalarTypeArgument(name, location);
                argumentNodes.push(argument);
                // fieldNode.addArgument(argument);
            }
            token = check self.peekNextNonSeparatorToken();
        }
        // If it comes to this, token.kind == T_CLOSE_BRACE. We consume it
        token = check self.readNextNonSeparatorToken();
        return argumentNodes;
    }

    isolated function addDirectivesToSelection(DirectiveLocation directiveLocation)
    returns DirectiveNode[]|Error {
        Token token = check self.peekNextNonSeparatorToken();
        DirectiveNode[] directiveNodes = [];
        if token.kind != T_AT {
            return directiveNodes;
        }
        while token.kind == T_AT {
            token = check self.readNextNonSeparatorToken(); //consume @
            Location location = token.location.clone();
            token = check self.readNextNonSeparatorToken();
            string name = check getIdentifierTokenvalue(token);
            token = check self.peekNextNonSeparatorToken();
            ArgumentNode[] argumentNodes = [];
            if token.kind == T_OPEN_PARENTHESES {
                argumentNodes = check self.addArgumentsToDirective(directiveLocation);
            }
            DirectiveNode directiveNode = new (name, location, directiveLocation, argumentNodes);
            directiveNodes.push(directiveNode);
            // ---> parentNode.addDirective(directiveNode);
            token = check self.peekNextNonSeparatorToken();
        }
        return directiveNodes;
    }

    isolated function addArgumentsToDirective(DirectiveLocation dirLocation) returns ArgumentNode[]|Error {
        Token token = check self.readNextNonSeparatorToken(); //consume (
        ArgumentNode[] argumentNodes = [];
        while token.kind != T_CLOSE_PARENTHESES {
            token = check self.readNextNonSeparatorToken();
            string varName = check getIdentifierTokenvalue(token);
            Location location = token.location.clone();
            token = check self.readNextNonSeparatorToken();
            if token.kind != T_COLON {
                return getExpectedCharError(token, COLON);
            }
            token = check self.peekNextNonSeparatorToken();
            if token.kind == T_OPEN_BRACE {
                if dirLocation == QUERY || dirLocation == MUTATION {
                    ArgumentNode argumentNode = check self.getInputObjectTypeArgument(varName, location, false);
                    argumentNodes.push(argumentNode);
                    // ---> directiveNode.addArgument(argumentNode);
                } else {
                    ArgumentNode argumentNode = check self.getInputObjectTypeArgument(varName, location);
                    argumentNodes.push(argumentNode);
                    // ---> directiveNode.addArgument(argumentNode);
                }
            } else if token.kind == T_OPEN_BRACKET {
                if dirLocation == QUERY || dirLocation == MUTATION {
                    ArgumentNode argumentNode = check self.getListTypeArgument(varName, location, false);
                    argumentNodes.push(argumentNode);
                    // ---> directiveNode.addArgument(argumentNode);
                } else {
                    ArgumentNode argumentNode = check self.getListTypeArgument(varName, location);
                    argumentNodes.push(argumentNode);
                    // ---> directiveNode.addArgument(argumentNode);
                }
            } else {
                if dirLocation == QUERY || dirLocation == MUTATION {
                    ArgumentNode argument = check self.getScalarTypeArgument(varName, location, false);
                    argumentNodes.push(argument);
                    // ---> directiveNode.addArgument(argument);
                } else {
                    ArgumentNode argument = check self.getScalarTypeArgument(varName, location);
                    argumentNodes.push(argument);
                    // ---> directiveNode.addArgument(argument);
                }
            }
            token = check self.peekNextNonSeparatorToken();
        }
        token = check self.readNextNonSeparatorToken();
        return argumentNodes;
    }

    isolated function getInputObjectTypeArgument(string name, Location location,
                                                 boolean isAllowVariableValue = true) returns ArgumentNode|Error {
        // ArgumentNode argumentNode = new (name, location, T_INPUT_OBJECT);
        ArgumentValue[] fields = [];
        string[] visitedFields = [];
        Token token = check self.readNextNonSeparatorToken(); // consume open brace here
        token = check self.peekNextNonSeparatorToken();
        Location valueLocation = token.location;
        // ---> argumentNode.setValueLocation(token.location);
        if token.kind != T_CLOSE_BRACE {
            while token.kind != T_CLOSE_BRACE {
                token = check self.readNextNonSeparatorToken();
                string fieldName = check getIdentifierTokenvalue(token);
                Location fieldLocation = token.location.clone();
                if visitedFields.indexOf(fieldName) != () {
                    return getDuplicateFieldError(token);
                }
                token = check self.readNextNonSeparatorToken();
                if token.kind != T_COLON {
                    return getExpectedCharError(token, COLON);
                }
                token = check self.peekNextNonSeparatorToken();
                if token.kind == T_OPEN_BRACE {
                    //nested input objects
                    ArgumentNode nestedInputObjectFields =
                        check self.getInputObjectTypeArgument(fieldName, fieldLocation, isAllowVariableValue);
                    fields.push(nestedInputObjectFields);
                    visitedFields.push(fieldName);
                } else if token.kind == T_OPEN_BRACKET {
                    //list with nested lists
                    ArgumentNode listTypeFieldValue = check self.getListTypeArgument(fieldName, token.location);
                    fields.push(listTypeFieldValue);
                    visitedFields.push(fieldName);
                } else if token.kind == T_DOLLAR {
                    if isAllowVariableValue {
                        //input object fields with variable definitions
                        token = check self.readNextNonSeparatorToken();
                        token = check self.readNextNonSeparatorToken();
                        string varName = check getIdentifierTokenvalue(token);
                        ArgumentNode nestedVariableFields = new (fieldName, token.location, T_IDENTIFIER,
                                                                 isVarDef = true, variableName = varName);
                        // nestedVariableFields.addVariableName(varName);
                        fields.push(nestedVariableFields);
                        visitedFields.push(fieldName);
                    } else {
                        return getUnexpectedTokenError(token);
                    }
                } else {
                    //input object fields with value
                    token = check self.readNextNonSeparatorToken();
                    ArgumentType argType = <ArgumentType>token.kind;
                    ArgumentValue fieldValue = check getArgumentValue(token);
                    ArgumentNode inputObjectFieldNode = new (fieldName, fieldLocation, argType, value = fieldValue, valueLocation = token.location);
                    // inputObjectFieldNode.setValue(fieldValue);
                    // inputObjectFieldNode.setValueLocation(token.location);
                    fields.push(inputObjectFieldNode);
                    visitedFields.push(fieldName);
                }
                token = check self.peekNextNonSeparatorToken();
            }
        }
        token = check self.readNextNonSeparatorToken(); // consume close brace here
        ArgumentNode argumentNode = new (name, location, T_INPUT_OBJECT, value = fields, valueLocation = valueLocation);
        // argumentNode.setValue(fields);
        return argumentNode;
    }

    isolated function getListTypeArgument(string name, Location location,
                                        boolean isAllowVariableValue = true) returns ArgumentNode|Error {
        Token token = check self.readNextNonSeparatorToken(); // consume open bracket here
        ArgumentValue[] listMembers = [];
        token = check self.peekNextNonSeparatorToken();
        Location valueLocation = token.location;
        // argumentNode.setValueLocation();
        if token.kind != T_CLOSE_BRACKET {
            while token.kind != T_CLOSE_BRACKET {
                token = check self.peekNextNonSeparatorToken();
                if token.kind == T_OPEN_BRACE {
                    //list with input objects
                    ArgumentNode inputObjectValue =
                        check self.getInputObjectTypeArgument(name, token.location, isAllowVariableValue);
                    listMembers.push(inputObjectValue);
                } else if token.kind == T_OPEN_BRACKET {
                    //list with nested lists
                    ArgumentNode listValue = check self.getListTypeArgument(name, token.location);
                    listMembers.push(listValue);
                } else if token.kind == T_DOLLAR {
                    if isAllowVariableValue {
                        //list with variables
                        token = check self.readNextNonSeparatorToken(); // consume dollar here
                        token = check self.readNextNonSeparatorToken();
                        string varName = check getIdentifierTokenvalue(token);
                        ArgumentNode variableValue = new (name, token.location, T_IDENTIFIER, isVarDef = true, variableName = varName);
                        // variableValue.addVariableName(varName);
                        listMembers.push(variableValue);
                    } else {
                        return getUnexpectedTokenError(token);
                    }
                } else if token.kind is ArgumentType {
                    //list with Scalar values
                    token = check self.readNextNonSeparatorToken();
                    ArgumentType argType = <ArgumentType>token.kind;
                    ArgumentValue value = check getArgumentValue(token);
                    ArgumentNode argumentValue = new (name, token.location, argType, value = value);
                    // argumentValue.setValue(value);
                    listMembers.push(argumentValue);
                } else {
                    return getUnexpectedTokenError(token);
                }
                token = check self.peekNextNonSeparatorToken();
            }
        }
        token = check self.readNextNonSeparatorToken(); // consume close bracket here
        ArgumentNode argumentNode = new (name, location, T_LIST, value = listMembers, valueLocation = valueLocation);
        // argumentNode.setValue(listMembers)
        return argumentNode;
    }

    isolated function getScalarTypeArgument(string name, Location location,
                                            boolean isAllowVariableValue = true) returns ArgumentNode|Error {
        Token token = check self.readNextNonSeparatorToken();
        if token.kind == T_DOLLAR {
            if isAllowVariableValue {
                //scalar type argument with variable definition
                token = check self.readNextNonSeparatorToken();
                string varName = check getIdentifierTokenvalue(token);
                ArgumentType argType = <ArgumentType>token.kind;
                ArgumentNode argument = new (name, token.location, argType, isVarDef = true, variableName = varName, valueLocation = token.location);
                // argument.addVariableName(varName);
                // argument.setValueLocation(token.location);
                return argument;
            }
            return getUnexpectedTokenError(token);
        } else {
            ArgumentValue value = check getArgumentValue(token);
            ArgumentType argType = <ArgumentType>token.kind;
            ArgumentNode argument = new (name, location, argType, value = value, valueLocation = token.location);
            // argument.setValue(value);
            // argument.setValueLocation(token.location);
            return argument;
        }
    }

    isolated function getNameWhenAliasPresent(string alias) returns string|Error {
        Token token = check self.peekNextNonSeparatorToken();
        if token.kind == T_COLON {
            token = check self.readNextNonSeparatorToken(); // Read colon
            token = check self.readNextNonSeparatorToken();
            return getIdentifierTokenvalue(token);
        }
        return alias;
    }

    isolated function getTypeIdentifierTokenValue(Token previousToken) returns string|Error {
        string varType;
        Token token;
        if previousToken.kind == T_OPEN_BRACKET {
            varType = previousToken.value.toString();
            token = check self.readNextNonSeparatorToken();
            varType += check self.getTypeIdentifierTokenValue(token);
            token = check self.readNextNonSeparatorToken();
            if token.kind != T_CLOSE_BRACKET {
                return getExpectedCharError(token, CLOSE_BRACKET);
            }
            varType += token.value.toString();
            token = check self.peekNextNonSeparatorToken();
            if token.kind == T_EXCLAMATION {
                token = check self.readNextNonSeparatorToken(); // Read exlamation
                varType += token.value.toString();
                return varType;
            }
        } else {
            varType = check getIdentifierTokenvalue(previousToken);
            token = check self.peekNextNonSeparatorToken();
            if token.kind == T_EXCLAMATION {
                token = check self.readNextNonSeparatorToken(); // Read exlamation
                varType += token.value.toString();
                return varType;
            }
        }
        return varType;
    }

    isolated function readNextNonSeparatorToken() returns Token|Error {
        Token token = check self.lexer.read();
        if token.kind is IgnoreType {
            return self.readNextNonSeparatorToken();
        }
        return token;
    }

    isolated function peekNextNonSeparatorToken() returns Token|Error {
        int i = 1;
        Token token = check self.lexer.peek(i);
        while true {
            if token.kind is LexicalType {
                break;
            }
            i += 1;
            token = check self.lexer.peek(i);
        }

        return token;
    }

    isolated function addOperationToMap(OperationNode operation) {
        if self.operations.hasKey(ANONYMOUS_OPERATION) {
            if !self.isFirstAnonymousOperationErrorPushed {
                OperationNode originalOperation = <OperationNode>self.operations[ANONYMOUS_OPERATION];
                self.errors.push(getAnonymousOperationInMultipleOperationsError(originalOperation));
                self.isFirstAnonymousOperationErrorPushed = true;
            }
            if operation.getName() == ANONYMOUS_OPERATION {
                self.errors.push(getAnonymousOperationInMultipleOperationsError(operation));
            }
            return;
        } else if operation.getName() == ANONYMOUS_OPERATION && self.operations.length() > 0 {
            self.errors.push(getAnonymousOperationInMultipleOperationsError(operation));
            self.isFirstAnonymousOperationErrorPushed = true;
            return;
        } else if self.operations.hasKey(operation.getName()) {
            OperationNode originalOperation = <OperationNode>self.operations[operation.getName()];
            string message = string `There can be only one operation named "${operation.getName()}".`;
            Location l1 = originalOperation.getLocation();
            Location l2 = operation.getLocation();
            self.errors.push({message: message, locations: [l1, l2]});
            return;
        }
        self.operations[operation.getName()] = operation;
    }

    isolated function addFragmentToMap(FragmentNode fragment) {
        if self.fragments.hasKey(fragment.getName()) {
            FragmentNode originalFragment = <FragmentNode>self.fragments[fragment.getName()];
            if fragment.isInlineFragment() {
                self.appendDuplicateInlineFragment(fragment, originalFragment);
            } else {
                string message = string `There can be only one fragment named "${fragment.getName()}".`;
                Location l1 = originalFragment.getLocation();
                Location l2 = fragment.getLocation();
                self.errors.push({message: message, locations: [l1, l2]});
                self.fragments[fragment.getName()] = fragment;
            }
        } else {
            self.fragments[fragment.getName()] = fragment;
        }
    }

    isolated function appendDuplicateInlineFragment(FragmentNode duplicate, FragmentNode original) {
        FragmentNode modifiedNode = original.modifyWith(selections = duplicate.getSelections());
        self.fragments[original.getName()] = modifiedNode;
    }

    public isolated function getErrors() returns ErrorDetail[] {
        return self.errors;
    }
}

isolated function getRootOperationType(Token token) returns RootOperationType|Error {
    string value = <string>token.value;
    if value is RootOperationType {
        return value;
    }
    return getUnexpectedTokenError(token);
}

isolated function getArgumentValue(Token token) returns ArgumentValue|Error {
    if token.kind is ArgumentType {
        return token.value == NULL ? () : token.value;
    }
    return getUnexpectedTokenError(token);
}

isolated function getOperationNameFromToken(Parser parser) returns string|Error {
    Token token = check parser.peekNextNonSeparatorToken();
    if token.kind == T_IDENTIFIER {
        // If this is a named operation, we should consume name token
        token = check parser.readNextNonSeparatorToken();
        return <string>token.value;
    }
    if token.kind == T_OPEN_BRACE || token.kind == T_OPEN_PARENTHESES || token.kind == T_AT {
        return ANONYMOUS_OPERATION;
    }
    return getUnexpectedTokenError(token);
}

isolated function getIdentifierTokenvalue(Token token) returns string|Error {
    if token.kind == T_IDENTIFIER {
        return <string>token.value;
    }
    return getExpectedNameError(token);
}

isolated function getLocationFromRootOperationType(RootOperationType operation) returns DirectiveLocation {
    if operation == OPERATION_SUBSCRIPTION {
        return SUBSCRIPTION;
    } else if operation == OPERATION_MUTATION {
        return MUTATION;
    }
    return QUERY;
}