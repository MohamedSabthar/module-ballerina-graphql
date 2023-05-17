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
import graphql.dataloader;
import ballerina/jballerina.java;
// import ballerina/io;

isolated class ExecutorVisitor {
    *parser:Visitor;

    private final readonly & __Schema schema;
    private final Engine engine; // This field needed to be accessed from the native code
    private Data data;
    private ErrorDetail[] errors;
    private Context context;
    private any|error result; // The value of this field is set using setResult method

    isolated function init(Engine engine, readonly & __Schema schema, Context context, any|error result = ()) {
        self.engine = engine;
        self.schema = schema;
        self.context = context;
        self.data = {};
        self.errors = [];
        self.result = ();
        self.setResult(result);
    }

    public isolated function visitDocument(parser:DocumentNode documentNode, anydata data = ()) {}

    public isolated function visitOperation(parser:OperationNode operationNode, anydata data = ()) {
        string[] path = [];
        if operationNode.getName() != parser:ANONYMOUS_OPERATION {
            path.push(operationNode.getName());
        }
        // if operationNode.getKind() != parser:OPERATION_MUTATION {
        //     map<anydata> dataMap = {[OPERATION_TYPE] : operationNode.getKind(), [PATH] : path};
        //     return self.visitSelectionsParallelly(operationNode, dataMap.cloneReadOnly());
        // }
        parser:SelectionNode[] selectionsForSecondPass = [];
        map<dataloader:DataLoader> dataLoaders = {};
        parser:RootOperationType operationType = operationNode.getKind();
        foreach parser:SelectionNode selection in operationNode.getSelections() {
            // if selection is parser:FieldNode {
            //     // TODO: execute selection which needs first pass, collect the name for second pass
            //     // execute them after first pass, self.engine.getService();
            //     string loadResourceMethodName = getLoadResourceMethodName(selection.getName());
            //     io:println("loadResourceMethodName: " + loadResourceMethodName);
            //     // TODO: implement this function
            //     // this function check for the loadXXX function with @Loader annotation and return the batch function from that annotation
            //     if hasLoadResourceMethod(self.engine.getService(), loadResourceMethodName) {
            //         (isolated function (readonly & anydata[] keys) returns anydata[]|error) batchLoadFunction = getBatchLoadFunction(self.engine.getService(), loadResourceMethodName);
            //         Context context;
            //         lock {
            //             context = self.context;
            //         }
            //         dataloader:DataLoader dataloader = context.getDataLoader(batchLoadFunction, loadResourceMethodName);
            //         dataLoaders[loadResourceMethodName] = dataloader;
            //         // TODO: modify this error|any return type. and push the errors to graphql errors
            //         self.executeLoadResource(getResourceMethod(self.engine.getService(), [loadResourceMethodName]), selection, operationType, loadResourceMethodName, dataloader);
            //         selectionsForSecondPass.push(selection);
            //         continue;
            //     }
            // }
            if selection is parser:FieldNode {
                path.push(selection.getName());
            }
            map<anydata> dataMap = {[OPERATION_TYPE] : operationNode.getKind(), [PATH] : path};
            selection.accept(self, dataMap);
        }
        dataLoaders.forEach(loader => checkpanic loader.dispatch());
        foreach parser:SelectionNode selection in selectionsForSecondPass {
            if selection is parser:FieldNode {
                path.push(selection.getName());
            }
            map<anydata> dataMap = {[OPERATION_TYPE] : operationNode.getKind(), [PATH] : path};
            selection.accept(self, dataMap);
        }
    }

    public isolated function visitField(parser:FieldNode fieldNode, anydata data = ()) {
        parser:RootOperationType operationType = self.getOperationTypeFromData(data);
        boolean isIntrospection = true;
        lock {
            if fieldNode.getName() == SCHEMA_FIELD {
            IntrospectionExecutor introspectionExecutor = new(self.schema);
            self.data[fieldNode.getAlias()] = introspectionExecutor.getSchemaIntrospection(fieldNode);
            } else if fieldNode.getName() == TYPE_FIELD {
                IntrospectionExecutor introspectionExecutor = new(self.schema);
                self.data[fieldNode.getAlias()] = introspectionExecutor.getTypeIntrospection(fieldNode);
            } else if fieldNode.getName() == TYPE_NAME_FIELD {
                if operationType == parser:OPERATION_QUERY {
                    self.data[fieldNode.getAlias()] = QUERY_TYPE_NAME;
                } else if operationType == parser:OPERATION_MUTATION {
                    self.data[fieldNode.getAlias()] = MUTATION_TYPE_NAME;
                } else {
                    self.data[fieldNode.getAlias()] = SUBSCRIPTION_TYPE_NAME;
                }
            } else {
                isIntrospection = false;
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
        parser:RootOperationType operationType = self.getOperationTypeFromData(data);
        // if operationType != parser:OPERATION_MUTATION {
        //     return self.visitSelectionsParallelly(fragmentNode, data);
        // }
        string[] path = self.getSelectionPathFromData(data);
        parser:SelectionNode[] selectionsForSecondPass = [];
        map<dataloader:DataLoader> dataLoaders = {};
        foreach parser:SelectionNode selection in fragmentNode.getSelections() {
            string[] clonedPath = path.clone();
            // if selection is parser:FieldNode {
            //     // TODO: execute selection which needs first pass, collect the name for second pass
            //     // execute them after first pass, self.engine.getService();
            //     string loadResourceMethodName = getLoadResourceMethodName(selection.getName());
            //     // TODO: implement this function
            //     // this function check for the loadXXX function with @Loader annotation and return the batch function from that annotation
            //     if hasLoadResourceMethod(self.engine.getService(), loadResourceMethodName) {
            //         io:println("loadResourceMethodName: " + loadResourceMethodName);
            //         (isolated function (readonly & anydata[] keys) returns anydata[]|error) batchLoadFunction = getBatchLoadFunction(self.engine.getService(), loadResourceMethodName);
            //         Context context;
            //         lock {
            //             context = self.context;
            //         }
            //         dataloader:DataLoader dataloader = context.getDataLoader(batchLoadFunction, loadResourceMethodName);
            //         dataLoaders[loadResourceMethodName] = dataloader;
            //         // TODO: modify this error|any return type. and push the errors to graphql errors
            //          self.executeLoadResource(getResourceMethod(self.engine.getService(), [loadResourceMethodName]), selection, operationType, loadResourceMethodName, dataloader);
            //         selectionsForSecondPass.push(selection);
            //         continue;
            //     }
            // }
            if selection is parser:FieldNode {
                clonedPath.push(selection.getName());
            }
            map<anydata> dataMap = {[OPERATION_TYPE] : operationType, [PATH] : clonedPath};
            selection.accept(self, dataMap);
        }
        dataLoaders.forEach(loader => checkpanic loader.dispatch());
        foreach parser:SelectionNode selection in selectionsForSecondPass {
            string[] clonedPath = path.clone();
            if selection is parser:FieldNode {
                clonedPath.push(selection.getName());
            }
            map<anydata> dataMap = {[OPERATION_TYPE] : operationType, [PATH] : clonedPath};
            selection.accept(self, dataMap);
        }
    }

    // private isolated function visitSelectionsParallelly(parser:SelectionParentNode selectionParentNode,
    //         readonly & anydata data = ()) {
    //     parser:RootOperationType operationType = self.getOperationTypeFromData(data);
    //     [parser:SelectionNode, future<()>][] selectionFutures = [];
    //     parser:SelectionNode[] selectionsForSecondPass = [];
    //     map<dataloader:DataLoader> dataLoaders = {};
    //     foreach parser:SelectionNode selection in selectionParentNode.getSelections() {
    //         if selection is parser:FieldNode {
    //             // TODO: execute selection which needs first pass, collect the name for second pass
    //             // execute them after first pass, self.engine.getService();
    //             string loadResourceMethodName = getLoadResourceMethodName(selection.getName());
    //             // TODO: implement this function
    //             // this function check for the loadXXX function with @Loader annotation and return the batch function from that annotation
    //             if hasLoadResourceMethod(self.engine.getService(), loadResourceMethodName) {
    //                 (isolated function (readonly & anydata[] keys) returns anydata[]|error) batchLoadFunction = getBatchLoadFunction(self.engine.getService(), loadResourceMethodName);
    //                 dataloader:DataLoader dataloader;
    //                 lock {
    //                     dataloader = self.context.getDataLoader(batchLoadFunction, loadResourceMethodName);
    //                 }
    //                 dataLoaders[loadResourceMethodName] = dataloader;
    //                 // TODO: modify this error|any return type. and push the errors to graphql errors
    //                 future<()> 'future = start self.executeLoadResource(getResourceMethod(self.engine.getService(), [loadResourceMethodName]), selection, operationType, loadResourceMethodName, dataloader);
    //                 selectionsForSecondPass.push(selection);
    //                 selectionFutures.push([selection, 'future]);
    //                 continue;
    //             }
    //         }
    //         string[] path = self.getSelectionPathFromData(data);
    //         if selection is parser:FieldNode {
    //             path.push(selection.getName());
    //         }
    //         map<anydata> dataMap = {[OPERATION_TYPE] : operationType, [PATH] : path};
    //         future<()> 'future = start selection.accept(self, dataMap.cloneReadOnly());
    //         selectionFutures.push([selection, 'future]);
    //     }

    //     foreach [parser:SelectionNode, future<()>] [selection, 'future] in selectionFutures {
    //         error? err = wait 'future;
    //         if err is () {
    //             continue;
    //         }
    //         log:printError("Error occured while attempting to resolve selection future", err,
    //                         stackTrace = err.stackTrace());
    //         lock {
    //             if selection is parser:FieldNode {
    //                 string[] path = self.getSelectionPathFromData(data);
    //                 path.push(selection.getName());
    //                 ErrorDetail errorDetail = {
    //                     message: err.message(),
    //                     locations: [selection.getLocation()],
    //                     path: path.clone()
    //                 };
    //                 self.data[selection.getAlias()] = ();
    //                 self.errors.push(errorDetail);
    //             }
    //         }
    //     }
    //     selectionFutures.removeAll();
    //     dataLoaders.forEach(loader => checkpanic loader.dispatch());
    //     // dataLoaders.removeAll(); 
    //     // TODO: visit 2nd pass selections and collect futures
    //     // TODO: visit 2nd pass futures

    //     foreach parser:SelectionNode selection in selectionsForSecondPass {
    //         string[] path = self.getSelectionPathFromData(data);
    //         if selection is parser:FieldNode {
    //             path.push(selection.getName());
    //         }
    //         map<anydata> dataMap = {[OPERATION_TYPE] : operationType, [PATH] : path};
    //         future<()> 'future = start selection.accept(self, dataMap.cloneReadOnly());
    //         selectionFutures.push([selection, 'future]);
    //     }

    //     foreach [parser:SelectionNode, future<()>] [selection, 'future] in selectionFutures {
    //         error? err = wait 'future;
    //         if err is () {
    //             continue;
    //         }
    //         log:printError("Error occured while attempting to resolve selection future", err,
    //                         stackTrace = err.stackTrace());
    //         lock {
    //             if selection is parser:FieldNode {
    //                 string[] path = self.getSelectionPathFromData(data);
    //                 path.push(selection.getName());
    //                 ErrorDetail errorDetail = {
    //                     message: err.message(),
    //                     locations: [selection.getLocation()],
    //                     path: path.clone()
    //                 };
    //                 self.data[selection.getAlias()] = ();
    //                 self.errors.push(errorDetail);
    //             }
    //         }
    //     }
    // }

    private isolated function executeLoadResource(handle? loadResourceMethod, parser:FieldNode fieldNode, parser:RootOperationType operationType, string loadResourceMethodName, dataloader:DataLoader dataloader) returns () {
        handle? loadResourceMethodHandle = getResourceMethod(self.engine.getService(), [loadResourceMethodName]);
        if loadResourceMethodHandle == () {
            return ();
        }
        return executeLoadResourceMethod(self.engine.getService(), loadResourceMethodHandle, dataloader);
    }

    public isolated function visitDirective(parser:DirectiveNode directiveNode, anydata data = ()) {}

    public isolated function visitVariable(parser:VariableNode variableNode, anydata data = ()) {}

    isolated function execute(parser:FieldNode fieldNode, parser:RootOperationType operationType) {
        any|error result;
        __Schema schema;
        Engine engine;
        Context context;
        lock {
            result = self.getResult();
            schema = self.schema;
            engine = self.engine;
            context = self.context;
        }
        Field 'field = getFieldObject(fieldNode, operationType, schema, engine, result);
        context.resetInterceptorCount();
        // Context clonedContext = context.cloneWithoutErrors();
        anydata resolvedResult = engine.resolve(context, 'field);
        // context.addErrors(clonedContext.getErrors());
        lock {
            self.errors = self.context.getErrors();
            self.data[fieldNode.getAlias()] = resolvedResult is ErrorDetail ? () : getFlatternedResult(context, resolvedResult.clone());
        }
    }

    isolated function getOutput() returns OutputObject {
        lock {
            return getOutputObject(self.data.clone(), self.errors.clone());
        }
    }

    private isolated function getSelectionPathFromData(anydata data) returns string[] {
        map<anydata> dataMap = <map<anydata>>data;
        string[] path = <string[]>dataMap[PATH];
        return [...path];
    }

    private isolated function getOperationTypeFromData(anydata data) returns parser:RootOperationType {
        map<anydata> dataMap = <map<anydata>>data;
        return <parser:RootOperationType>dataMap[OPERATION_TYPE];
    }

    private isolated function setResult(any|error result) =  @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    private isolated function getResult() returns any|error =  @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
    } external;
}

isolated function getLoadResourceMethodName(string fieldName) returns string {
    string loadResourceMethodName = "load" +string:toUpperAscii(fieldName.substring(0, 1));
    if fieldName.length() > 1 {
        loadResourceMethodName += fieldName.substring(1);
    }
    return loadResourceMethodName;
}

isolated function hasLoadResourceMethod(service object {} serviceObject, string loadResourceMethodName) returns boolean = @java:Method {
    'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
} external;

isolated function getBatchLoadFunction(service object {} serviceObject, string loadResourceMethodName) 
returns (isolated function (readonly & anydata[] keys) returns anydata[]|error) = @java:Method {
    'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
} external;

isolated function executeLoadResourceMethod(service object {} serviceObject, handle loadResourceMethod, dataloader:DataLoader dataloader) returns () = @java:Method {
    'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
} external;

isolated function getFlatternedResult(Context context, anydata partialValue) returns anydata {
    // io:println("partialValue", partialValue);
    // if context.getUnresolvedPlaceHolderCount() < 1 {
    //     return partialValue;
    // }
    while context.getUnresolvedPlaceHolderCount() > 0 {
        // io:println("Looping....", context.getUnresolvedPlaceHolderCount());
        context.resolvePlaceHolders();
    }
    if partialValue is PloaceHolderNode {
        anydata value = context.getPlaceHolderValue(partialValue.hashCode);
        // io:println("value", value);
        anydata flattenedValue = getFlatternedResult(context, value);
        // io:println("flattenedValue", flattenedValue);
        anydata result = flattenedValue;
        // context.decrementPlaceHolderCount();
        return result;
    }
    if partialValue is record {} {
        return getFlatternedResultFromRecord(context, partialValue);
    }
    if partialValue is anydata[] {
        return getFlatternedResultFromArray(context, partialValue);
    }
    return partialValue;
}

isolated function getFlatternedResultFromRecord(Context context, record{} partialValue) returns anydata {
    Data data = {};
    foreach [string,anydata] [key, value] in partialValue.entries() {
        data[key] = getFlatternedResult(context, value);
    }
    return data;
}

isolated function getFlatternedResultFromArray(Context context, anydata[] partialValue) returns anydata {
    anydata[] data = [];
    foreach anydata element in partialValue {
        anydata newVal = getFlatternedResult(context, element);
        data.push(newVal);
    }
    return data;
}