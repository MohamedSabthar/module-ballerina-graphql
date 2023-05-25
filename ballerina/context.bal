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

import ballerina/http;
import ballerina/jballerina.java;
import ballerina/lang.value;
import graphql.dataloader;

# The GraphQL context object used to pass the meta information between resolvers.
public isolated class Context {
    private final map<value:Cloneable|isolated object {}> attributes;
    private final ErrorDetail[] errors;
    private Engine? engine;
    private int nextInterceptor;
    private boolean hasFileInfo = false; // This field value changed by setFileInfo method
    private map<dataloader:DataLoader> dataLoaderCache = {};
    private map<PlaceHolder[]> dataLoaderToPlaceHolderMap = {};
    private map<PlaceHolder> placeHolders = {};
    private int placeHolderCount = 0;

    public isolated function init(map<value:Cloneable|isolated object {}> attributes = {}, Engine? engine = (), 
                                  int nextInterceptor = 0) {
        self.attributes = {};
        self.engine = engine;
        self.errors = [];
        self.nextInterceptor = nextInterceptor;
        
        foreach var item in attributes.entries() {
            string key = item[0];
            value:Cloneable|isolated object {} value = item[1];
            self.attributes[key] = value;
        }
    }

    isolated function setDataLoaderCache(map<dataloader:DataLoader> dataLoaderCache) = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    # Sets a given value for a given key in the GraphQL context.
    #
    # + key - The key for the value to be set
    # + value - Value to be set
    public isolated function set(string 'key, value:Cloneable|isolated object {} value) {
        lock {
            if value is value:Cloneable {
                self.attributes['key] = value.clone();
            } else {
                self.attributes['key] = value;
            }
        }
    }

    # Retrieves a value using the given key from the GraphQL context.
    #
    # + key - The key corresponding to the required value
    # + return - The value if the key is present in the context, a `graphql:Error` otherwise
    public isolated function get(string 'key) returns value:Cloneable|isolated object {}|Error {
        lock {
            if self.attributes.hasKey('key) {
                value:Cloneable|isolated object {} value = self.attributes.get('key);
                if value is value:Cloneable {
                    return value.clone();
                } else {
                    return value;
                }
            }
            return error Error(string`Attribute with the key "${'key}" not found in the context`);
        }
    }

    # Removes a value using the given key from the GraphQL context.
    #
    # + key - The key corresponding to the value to be removed
    # + return - The value if the key is present in the context, a `graphql:Error` otherwise
    public isolated function remove(string 'key) returns value:Cloneable|isolated object {}|Error {
        lock {
            if self.attributes.hasKey('key) {
                value:Cloneable|isolated object {} value = self.attributes.remove('key);
                if value is value:Cloneable {
                    return value.clone();
                } else {
                    return value;
                }
            }
            return error Error(string`Attribute with the key "${'key}" not found in the context`);
        }
    }

    isolated function addError(ErrorDetail err) {
        lock {
            self.errors.push(err.clone());
        }
    }

    isolated function addErrors(ErrorDetail[] errs) {
        readonly & ErrorDetail[] errors = errs.cloneReadOnly();
        lock {
            self.errors.push(...errors);
        }
    }

    isolated function getErrors() returns ErrorDetail[] {
        lock {
            return self.errors.clone();
        }
    }

    isolated function setFileInfo(map<Upload|Upload[]> fileInfo) = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    isolated function getFileInfo() returns map<Upload|Upload[]> = @java:Method {
        'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    // change this as a native method call and collect the results replace the placeholders and retur
    public isolated function resolve(Field 'field) returns anydata {
        Engine? engine = self.getEngine();
        if engine is Engine {
            return engine.resolve(self, 'field, false);
            // TODO: need to fix engine returns PlaceHolderNode record when intercepting
        }
        return;
    }

    public isolated function resolvePlaceHolders() {
        lock{
            map<PlaceHolder[]> dataLoaderToPlaceHolderMap = self.dataLoaderToPlaceHolderMap;
            self.dataLoaderToPlaceHolderMap = {};
            foreach [string, PlaceHolder[]] [key, placeHolders] in dataLoaderToPlaceHolderMap.entries() {
                // TODO: Fix checkpanic here, need to return a Error detaisl for these keys
                checkpanic self.dataLoaderCache.get(key).dispatch();
                foreach PlaceHolder placeHolder in placeHolders {
                    Engine? engine = self.getEngine();
                    anydata resolvedVal = ();
                    if engine is Engine {
                        resolvedVal = engine.resolve(self, 'placeHolder.getFieldValue(), false);
                    }
                    placeHolder.setValue(resolvedVal);
                    self.placeHolderCount-=1;
                }
            }
        }
    }

    isolated function setEngine(Engine engine) {
        lock {
            self.engine = engine;
        }
    }

    isolated function getEngine() returns Engine? {
        lock {
            return self.engine;
        }
    }

    isolated function getNextInterceptor(Field 'field) returns (readonly & Interceptor)? {
        Engine? engine = self.getEngine();
        if engine is Engine {
            (readonly & Interceptor)[] interceptors = engine.getInterceptors();
            if interceptors.length() > self.getInterceptorCount() {
                (readonly & Interceptor) next = interceptors[self.getInterceptorCount()];
                if !isGlobalInterceptor(next) && 'field.getPath().length() > 1 {
                    self.increaseInterceptorCount();
                    return self.getNextInterceptor('field);
                }
                self.increaseInterceptorCount();
                return next;
            }
            int nextFieldInterceptor = self.getInterceptorCount() - engine.getInterceptors().length();
            if 'field.getFieldInterceptors().length() > nextFieldInterceptor {
                readonly & Interceptor next = 'field.getFieldInterceptors()[nextFieldInterceptor];
                self.increaseInterceptorCount();
                return next;
            }
        }
        self.resetInterceptorCount();
        return;
    }

    isolated function resetInterceptorCount() {
        lock {
            self.nextInterceptor = 0;
        }
    }

    isolated function getInterceptorCount() returns int {
        lock {
            return self.nextInterceptor;
        }
    }

    isolated function increaseInterceptorCount() {
        lock {
            self.nextInterceptor += 1;
        }
    }

    isolated function resetErrors() {
        lock {
            self.errors.removeAll();
        }
    }

    isolated function addDataLoader((isolated function (readonly & anydata[] keys)
    returns anydata[]|error) batchFunction, string loadResourceMethodName) {
        lock {
            if self.dataLoaderCache.hasKey(loadResourceMethodName) {
                return;
            }
            dataloader:DefaultDataLoader dataloader = new(batchFunction);
            self.dataLoaderCache[loadResourceMethodName] = dataloader;
            return;
        }
    }

    isolated function getPlaceHolderValue(string hashCode) returns anydata {
        lock {
            return self.placeHolders.remove(hashCode).getValue();
        }
    }

    isolated function getUnresolvedPlaceHolderCount() returns int {
        lock {
            return self.placeHolderCount;
        }
    }

    isolated function addPlaceHolder(string 'key, PlaceHolder placeHolder) {
        lock {
            string hashCode = getHashCode(placeHolder);
            self.placeHolders[hashCode] = placeHolder;
            self.placeHolderCount+=1;

            if self.dataLoaderToPlaceHolderMap.hasKey('key) {
                PlaceHolder[] placeHolders = self.dataLoaderToPlaceHolderMap.get('key);
                placeHolders.push(placeHolder);
            } else {
                PlaceHolder[] placeHolders = [placeHolder];
                self.dataLoaderToPlaceHolderMap['key] = placeHolders;
            }
        }
    }
}

isolated function initDefaultContext(http:RequestContext requestContext, http:Request request) returns Context|error {
    return new;
}

isolated function getHashCode(object{} obj) returns string = @java:Method {
    'class: "io.ballerina.stdlib.graphql.runtime.engine.EngineUtils"
} external;