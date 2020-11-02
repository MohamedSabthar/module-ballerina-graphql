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

public class Engine {
    private Listener 'listener;
    private string[] fields;
    private Error[] errors;

    public isolated function init(Listener 'listener) {
        self.'listener = 'listener;
        self.fields = [];
        self.errors = [];
    }

    isolated function addService(service s) {
        self.fields = getFieldNames(s);
    }

    isolated function getListener() returns Listener {
        return self.'listener;
    }

    isolated function getFields() returns string[] {
        return self.fields;
    }

    isolated function validate(string documentString) returns Document|Error {
        Parser parser = check new(documentString);
        Document|Error parseResult = parser.parse();
        if (parseResult is Error) {
            return parseResult;
        }
        Document document = <Document>parseResult;
        var validationResult = self.validateDocument(document);
        if (validationResult is ValidationError) {
            return validationResult;
        }
        return document;
    }

    isolated function validateDocument(Document document) returns ValidationError? {
        self.validateOperations(document.operations);
    }

    isolated function validateOperations(Operation[] operations) {
        boolean multipleOperations = operations.length() > 1;

        foreach Operation operation in operations {
            if (multipleOperations && operation.name is ANONYMOUS_OPERATION) {
                DuplicateOperationError err = getMultipleAnonymousOperationsError(operation);
                self.errors.push(err);
            }
            self.validateOperation(operation);
        }
    }

    isolated function validateOperation(Operation operation) {
        Field[] fields = operation.fields;
        foreach Field 'field in fields {
            var validateResult = validateField(self.'listener, 'field, operation.'type);
            if (validateResult is Error[]) {
                self.errors = validateResult;
            }
        }
    }

    isolated function execute(Document document, string operationName) returns json {
        //map<json> data = {};
        //json[] errors = [];
        //int errorCount = 0;
        //map<Operation> operations = document.operations;
        //if (!operations.hasKey(operationName)) {
        //    string message = "Unknown operation named \"" + operationName + "\".";
        //    OperationNotFoundError err = OperationNotFoundError(message);
        //    errors[errorCount] = getErrorJsonFromError(err);
        //    return getResultJson(data, errors);
        //}
        //Operation operation = document.operations.get(operationName);
        //Field[] fields = operation.fields;
        //foreach Field 'field in fields {
        //    var resourceValue = executeResource(self.'listener, 'field);
        //    if (resourceValue is error) {
        //        string message = resourceValue.message();
        //        ErrorRecord errorRecord = getErrorRecordFromField('field);
        //        ExecutionError err = ExecutionError(message, errorRecord = errorRecord);
        //        errors[errorCount] = getErrorJsonFromError(err);
        //        errorCount += 1;
        //    } else if (resourceValue is ()) {
        //        data['field.name] = null;
        //    } else {
        //        data['field] = resourceValue;
        //    }
        //}
        //return getResultJson(data, errors);
    }
}
