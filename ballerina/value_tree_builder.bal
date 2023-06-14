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

isolated class ValueTreeBuilder {
    private Context context;
    private Data placeHolderTree;

    isolated function init(Context context, Data placeHolderTree) {
        self.context = context;
        self.placeHolderTree = placeHolderTree.clone();
    }

    isolated function build() returns anydata {
        lock {
            return self.buildResultTree(self.context, self.placeHolderTree).clone();
        }
    }

    isolated function buildResultTree(Context context, anydata partialValue) returns anydata {
        while context.getUnresolvedPlaceHolderCount() > 0 {
            context.resolvePlaceHolders();
        }
        if partialValue is ErrorDetail {
            return partialValue;
        }
        if partialValue is PlaceHolderNode {
            anydata value = context.getPlaceHolderValue(partialValue.__uuid);
            return self.buildResultTree(context, value);
        }
        if partialValue is map<anydata> && isMap(partialValue) {
            return self.buildResultTreeFromMap(context, partialValue);
        }
        if partialValue is record {} {
            return self.buildResultTreeFromRecord(context, partialValue);
        }
        if partialValue is anydata[] {
            return self.buildResultTreeFromArray(context, partialValue);
        }
        return partialValue;
    }

    isolated function buildResultTreeFromMap(Context context, map<anydata> partialValue) returns anydata {
        map<anydata> data = {};
        foreach [string, anydata] [key, value] in partialValue.entries() {
            data[key] = self.buildResultTree(context, value);
        }
        return data;
    }

    isolated function buildResultTreeFromRecord(Context context, record {} partialValue) returns anydata {
        record {} data = {};
        foreach [string, anydata] [key, value] in partialValue.entries() {
            data[key] = self.buildResultTree(context, value);
        }
        return data;
    }

    isolated function buildResultTreeFromArray(Context context, anydata[] partialValue) returns anydata {
        anydata[] data = [];
        foreach anydata element in partialValue {
            anydata newVal = self.buildResultTree(context, element);
            data.push(newVal);
        }
        return data;
    }
}
