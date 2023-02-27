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

isolated class ExecutorVisitor {
    *parser:Visitor;

    private final __Schema schema;
    private final Engine engine; // This field needed to be accessed from the native code
    private Data data;
    private ErrorDetail[] errors;
    private Context context;
    private readonly & any|error result;

    isolated function init(Engine engine, __Schema schema, Context context, readonly & any|error result = ()) {
        self.engine = engine;
        self.schema = schema.clone();
        self.context = context;
        self.data = {};
        self.result = result;
        self.errors = [];
    }

    public isolated function visitDocument(parser:DocumentNode documentNode, anydata data = ()) {}

    public isolated function visitOperation(parser:OperationNode operationNode, anydata data = ()) {
        if operationNode.getKind() == parser:OPERATION_MUTATION {
            foreach parser:SelectionNode selection in operationNode.getSelections() {
                selection.accept(self, operationNode.getKind());
            }
        } else {
            future<()>[] futures = [];
            foreach parser:SelectionNode selection in operationNode.getSelections() {
                future<()> 'future = start selection.accept(self, operationNode.getKind());
                futures.push('future);
            }
            foreach future<()> 'future in futures {
                _ = checkpanic wait 'future;
            }
        }
    }

    public isolated function visitField(parser:FieldNode fieldNode, anydata data = ()) {
        parser:RootOperationType operationType = <parser:RootOperationType>data;
        boolean isIntrospection = false;
        lock {
            if fieldNode.getName() == SCHEMA_FIELD {
            IntrospectionExecutor introspectionExecutor = new(self.schema);
            self.data[fieldNode.getAlias()] = introspectionExecutor.getSchemaIntrospection(fieldNode);
            isIntrospection = true;
            } else if fieldNode.getName() == TYPE_FIELD {
                IntrospectionExecutor introspectionExecutor = new(self.schema);
                self.data[fieldNode.getAlias()] = introspectionExecutor.getTypeIntrospection(fieldNode);
                isIntrospection = true;
            } else if fieldNode.getName() == TYPE_NAME_FIELD {
                if operationType == parser:OPERATION_QUERY {
                    self.data[fieldNode.getAlias()] = QUERY_TYPE_NAME;
                } else if operationType == parser:OPERATION_MUTATION {
                    self.data[fieldNode.getAlias()] = MUTATION_TYPE_NAME;
                } else {
                    self.data[fieldNode.getAlias()] = SUBSCRIPTION_TYPE_NAME;
                }
                isIntrospection = true;
            }
        }
        function (parser:FieldNode, parser:RootOperationType) execute;
        lock {
            execute = self.execute;
        }
        if !isIntrospection {
            execute(fieldNode, operationType);
        }
    }

    public isolated function visitArgument(parser:ArgumentNode argumentNode, anydata data = ()) {}

    public isolated function visitFragment(parser:FragmentNode fragmentNode, anydata data = ()) {
        // make this parallel
        future<()>[] futures = [];
        readonly & anydata clonedData = data.cloneReadOnly();
        foreach parser:SelectionNode selection in fragmentNode.getSelections() {
            future<()> 'future = start selection.accept(self, clonedData);
            futures.push('future);
        }
        foreach future<()> 'future in futures {
            _ = checkpanic wait 'future;
        }
    }

    public isolated function visitDirective(parser:DirectiveNode directiveNode, anydata data = ()) {}

    public isolated function visitVariable(parser:VariableNode variableNode, anydata data = ()) {}

    isolated function execute(parser:FieldNode fieldNode, parser:RootOperationType operationType) {
        readonly & any|error result;
        __Schema schema;
        Engine engine;
        Context context;
        lock {
            result = self.result.clone();
            schema = self.schema.clone();
            engine = self.engine;
            context = self.context;
        }
        Field 'field = getFieldObject(fieldNode, operationType, schema, engine, result.clone());
        context.resetInterceptorCount();
        readonly & anydata resolvedResult = engine.resolve(context, 'field);
        lock {
            self.errors = self.context.getErrors();
            self.data[fieldNode.getAlias()] = resolvedResult is ErrorDetail ? () : resolvedResult;
        }
    }

    isolated function getOutput() returns OutputObject {
        lock {
            return getOutputObject(self.data.clone(), self.errors.clone());
        }
    }
}
