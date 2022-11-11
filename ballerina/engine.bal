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

import ballerina/jballerina.java;

import graphql.parser;

isolated class Engine {
    private final readonly & __Schema schema;
    private final int? maxQueryDepth;
    private final readonly & (readonly & Interceptor)[] interceptors;
    private final readonly & boolean introspection;

    isolated function init(string schemaString, int? maxQueryDepth, Service s,
                           readonly & (readonly & Interceptor)[] interceptors, boolean introspection)
    returns Error? {
        if maxQueryDepth is int && maxQueryDepth < 1 {
            return error Error("Max query depth value must be a positive integer");
        }
        self.maxQueryDepth = maxQueryDepth;
        self.schema = check createSchema(schemaString);
        self.interceptors = interceptors;
        self.introspection = introspection;
        self.addService(s);
    }

    isolated function getSchema() returns readonly & __Schema {
        return self.schema;
    }

    isolated function getInterceptors() returns (readonly & Interceptor)[] {
        return self.interceptors;
    }

    isolated function validate(string documentString, string? operationName, map<json>? variables)
        returns parser:OperationNode|OutputObject {

        parser:DocumentNode|OutputObject result = self.parse(documentString);
        if result is OutputObject {
            return result;
        }
        parser:DocumentNode document = <parser:DocumentNode>result;
        OutputObject|parser:DocumentNode validationResult = self.validateDocument(document, variables);
        if validationResult is OutputObject {
            return validationResult;
        } else {
            document = validationResult; // updated tree
            return self.getOperation(document, operationName);
        }
    }

    isolated function getResult(parser:OperationNode operationNode, Context context, any|error result = ())
    returns OutputObject {
        map<parser:Node> removedNodes = {};
        // DefaultDirectiveProcessorVisitor defaultDirectiveProcessor = new (self.schema, removedNodes);
        DuplicateFieldRemoverVisitor duplicateFieldRemover = new(removedNodes);

        parser:Visitor[] updatingVisitors = [
            // defaultDirectiveProcessor,
            duplicateFieldRemover
        ];

        foreach parser:Visitor visitor in updatingVisitors {
            operationNode.accept(visitor);
        }

        ExecutorVisitor executor = new (self, self.schema, context, removedNodes, result);
        operationNode.accept(executor);
        OutputObject outputObject = executor.getOutput();
        ResponseFormatter responseFormatter = new (self.schema);
        return responseFormatter.getCoercedOutputObject(outputObject, operationNode);
    }

    isolated function parse(string documentString) returns parser:DocumentNode|OutputObject {
        parser:Parser parser = new (documentString);
        parser:DocumentNode|parser:Error parseResult = parser.parse();
        if parseResult is parser:DocumentNode {
            return parseResult;
        }
        ErrorDetail errorDetail = getErrorDetailFromError(<parser:Error>parseResult);
        return getOutputObjectFromErrorDetail(errorDetail);
    }

    isolated function validateDocument(parser:DocumentNode document, map<json>? variables) returns OutputObject|parser:DocumentNode {
        ErrorDetail[] validationErrors = []; // parser.getErrors should call somewhere
        map<()> fragmentWithCycles = {};
        map<()> unknowFragments = {};
        map<parser:FragmentNode> modifiedFragments = {};
        map<parser:ArgumentNode> modfiedArgumentNodes = {};
        ValidatorVisitor[] validators = [
            new FragmentCycleFinderVisitor(document.getFragments(), fragmentWithCycles), // no change
            new FragmentValidatorVisitor(document.getFragments(), fragmentWithCycles, unknowFragments, modifiedFragments), // modify frag nodes
            new QueryDepthValidatorVisitor(self.maxQueryDepth, modifiedFragments), // no change
            new VariableValidatorVisitor(self.schema, variables, modifiedFragments, modfiedArgumentNodes), // modify arg nodes
            new FieldValidatorVisitor(self.schema, fragmentWithCycles, unknowFragments, modifiedFragments, modfiedArgumentNodes), // modify arg node
            new DirectiveValidatorVisitor(self.schema, modifiedFragments, modfiedArgumentNodes), // no change
            new SubscriptionValidatorVisitor(modifiedFragments) // no change but uses modifed ones
        ];
        if !self.introspection {
            validators.push(new IntrospectionValidatorVisitor(self.introspection, modifiedFragments)); // no change
        }

        foreach ValidatorVisitor validator in validators {
            document.accept(validator);
            ErrorDetail[]? errors = validator.getErrors();
            if errors is ErrorDetail[] {
                validationErrors.push(...errors);
            }
        }
        if validationErrors.length() > 0 {
            return getOutputObjectFromErrorDetail(validationErrors);
        } else {
            TreeModifierVisitor treeModifierVisitor = new(modifiedFragments, modfiedArgumentNodes);
             document.accept(treeModifierVisitor);
             return treeModifierVisitor.getDocumentNode();
        }
    }

    isolated function getOperation(parser:DocumentNode document, string? operationName)
    returns parser:OperationNode|OutputObject {
        if operationName == () {
            if document.getOperations().length() == 1 {
                return document.getOperations()[0];
            } else {
                string message = string `Must provide operation name if query contains multiple operations.`;
                ErrorDetail errorDetail = {
                    message: message,
                    locations: []
                };
                return getOutputObjectFromErrorDetail(errorDetail);
            }
        } else {
            foreach parser:OperationNode operationNode in document.getOperations() {
                if operationName == operationNode.getName() {
                    return operationNode;
                }
            }
            string message = string `Unknown operation named "${operationName}".`;
            ErrorDetail errorDetail = {
                message: message,
                locations: []
            };
            return getOutputObjectFromErrorDetail(errorDetail);
        }
    }

    isolated function resolve(Context context, Field 'field) returns anydata {
        parser:FieldNode fieldNode = 'field.getInternalNode();
        parser:RootOperationType operationType = 'field.getOperationType();
        (Interceptor & readonly)? interceptor = context.getNextInterceptor();
        __Type fieldType = 'field.getFieldType();
        any|error fieldValue;
        if operationType == parser:OPERATION_QUERY {
            if interceptor is () {
                fieldValue = self.resolveResourceMethod(context, 'field);
            } else {
                any|error result = self.executeInterceptor(interceptor, 'field, context);
                anydata|error interceptValue = validateInterceptorReturnValue(fieldType, result,
                                                                              self.getInterceptorName(interceptor));
                if interceptValue is error {
                    fieldValue = interceptValue;
                } else {
                    return interceptValue;
                }
            }
        } else if operationType == parser:OPERATION_MUTATION {
            if interceptor is () {
                fieldValue = self.resolveRemoteMethod(context, 'field);
            } else {
                any|error result = self.executeInterceptor(interceptor, 'field, context);
                anydata|error interceptValue = validateInterceptorReturnValue(fieldType, result,
                                                                              self.getInterceptorName(interceptor));
                if interceptValue is error {
                    fieldValue = interceptValue;
                } else {
                    return interceptValue;
                }
            }
        } else {
            if interceptor is () {
                fieldValue = 'field.getFieldValue();
            } else {
                any|error result = self.executeInterceptor(interceptor, 'field, context);
                anydata|error interceptValue = validateInterceptorReturnValue(fieldType, result,
                                                                              self.getInterceptorName(interceptor));
                if interceptValue is error {
                    fieldValue = interceptValue;
                } else {
                    return interceptValue;
                }
            }
        }
        ResponseGenerator responseGenerator = new (self, context, fieldType, 'field.getPath().clone(), 'field.getRemovedNodesMap());
        return responseGenerator.getResult(fieldValue, fieldNode);
    }

    isolated function resolveResourceMethod(Context context, Field 'field) returns any|error {
        service object {}? serviceObject = 'field.getServiceObject();
        if serviceObject is service object {} {
            handle? resourceMethod = self.getResourceMethod(serviceObject, 'field.getResourcePath());
            if resourceMethod == () {
                return self.resolveHierarchicalResource(context, 'field);
            }
            return self.executeQueryResource(context, serviceObject, resourceMethod, 'field.getInternalNode());
        }
        return 'field.getFieldValue();
    }

    isolated function resolveRemoteMethod(Context context, Field 'field) returns any|error {
        service object {}? serviceObject = 'field.getServiceObject();
        if serviceObject is service object {} {
           return self.executeMutationMethod(context, serviceObject, 'field.getInternalNode());
        }
        return 'field.getFieldValue();
    }

    isolated function resolveHierarchicalResource(Context context, Field 'field) returns anydata {
        if 'field.getInternalNode().getSelections().length() == 0 {
            return;
        }
        map<anydata> result = {};
        foreach parser:SelectionNode selection in 'field.getInternalNode().getSelections() {
            if selection is parser:FieldNode {
                self.getHierarchicalResult(context, 'field, selection, result);
            } else if selection is parser:FragmentNode {
                self.resolveHierarchicalResourceFromFragment(context, 'field, selection, result);
            }
        }
        return result;
    }

    isolated function resolveHierarchicalResourceFromFragment(Context context, Field 'field,
                                                              parser:FragmentNode fragmentNode, map<anydata> result) {
        foreach parser:SelectionNode selection in fragmentNode.getSelections() {
            if selection is parser:FieldNode {
                self.getHierarchicalResult(context, 'field, selection, result);
            } else if selection is parser:FragmentNode {
                self.resolveHierarchicalResourceFromFragment(context, 'field, selection, result);
            }
        }
    }

    isolated function getHierarchicalResult(Context context, Field 'field, parser:FieldNode fieldNode, map<anydata> result) {
        string[] resourcePath = 'field.getResourcePath();
        (string|int)[] path = 'field.getPath().clone();
        path.push(fieldNode.getName());
        __Type fieldType = getFieldTypeFromParentType('field.getFieldType(), self.schema.types, fieldNode);
        Field selectionField = new (fieldNode, fieldType, 'field.getServiceObject(), path = path, resourcePath = resourcePath);
        context.resetInterceptorCount();
        anydata fieldValue = self.resolve(context, selectionField);
        result[fieldNode.getAlias()] = fieldValue is ErrorDetail ? () : fieldValue;
        _ = resourcePath.pop();
    }

    isolated function addService(Service s) = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    isolated function getService() returns Service = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    isolated function getResourceMethod(service object {} serviceObject, string[] path)
    returns handle? = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.Engine"
    } external;

    isolated function executeQueryResource(Context context, service object {} serviceObject, handle resourceMethod,
                                            parser:FieldNode fieldNode)
    returns any|error = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.Engine"
    } external;

    isolated function executeMutationMethod(Context context, service object {} serviceObject,
                                            parser:FieldNode fieldNode) returns any|error = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.Engine"
    } external;

    isolated function executeSubscriptionResource(Context context, service object {} serviceObject,
                                                  parser:FieldNode node) returns any|error = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.Engine"
    } external;

    isolated function executeInterceptor(readonly & Interceptor interceptor, Field fieldNode, Context context)
    returns any|error = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.Engine"
    } external;

    isolated function getInterceptorName(readonly & Interceptor interceptor) returns string = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.Engine"
    } external;
}
