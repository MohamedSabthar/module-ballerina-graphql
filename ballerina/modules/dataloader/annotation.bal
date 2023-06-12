// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

# Provides a set of configurations for the load resource method.
# + id - The id field allows reusing the DataLoader in different GraphQL fields
# + batchFunction - The batch function to be used in the DataLoader
public type LoaderConfig record {|
    string id?;
    (isolated function (readonly & anydata[] keys) returns anydata[]|error) batchFunction;
|};

# The annotation to configure the load resource method with a DataLoader.
public annotation  LoaderConfig  Loader on object function;