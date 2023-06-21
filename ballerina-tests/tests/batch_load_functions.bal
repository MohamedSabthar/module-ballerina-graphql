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

isolated function authorLoaderFunction(readonly & anydata[] ids) returns AuthorRow[]|error {
    readonly & int[] keys = <readonly & int[]>ids;
    // simulate the following database query
    // SELECT * FROM authors WHERE id IN (...keys);
    lock {
        dispatchCountForAuthorField += 1;
    }
    lock {
        readonly & int[] validKeys = keys.'filter(key => authorTable.hasKey(key)).cloneReadOnly();
        if keys.length() != validKeys.length() {
            return error("Invalid keys found for authors");
        }
        return validKeys.'map(key => authorTable.get(key));
    }
};

isolated function bookLoaderFunction(readonly & anydata[] ids) returns BookRow[][]|error {
    final readonly & int[] keys = <readonly & int[]>ids;
    // simulate the following database query
    // SELECT * FROM books WHERE author IN (...keys);
    lock {
        dispatchCountForBookField += 1;
    }
    return keys.'map(isolated function(readonly & int key) returns BookRow[] {
        lock {
            return bookTable.'filter(book => book.author == key).toArray().clone();
        }
    });
};

isolated function authorUpdateLoaderFunction(readonly & anydata[] idNames) returns AuthorRow[]|error {
    readonly & [int, string][] idValuePair = <readonly & [int, string][]>idNames;
    // simulate batch udpate
    lock {
        dispatchCountForUpdateAuthorNameField += 1;
    }
    lock {
        AuthorRow[] updatedAuthorRows = [];
        foreach [int, string] [key, name] in idValuePair {
            if !authorTable.hasKey(key) {
                return error(string `Invalid key author key found: ${key}`);
            }
            AuthorRow authorRow = {id: key, name};
            authorTable.put(authorRow);
            updatedAuthorRows.push(authorRow.clone());
        }
        return updatedAuthorRows.clone();
    }
};

isolated function faultyAuthorLoaderFunction(readonly & anydata[] ids) returns AuthorRow[]|error {
    readonly & int[] keys = <readonly & int[]>ids;
    lock {
        readonly & int[] validKeys = keys.'filter(key => authorTable.hasKey(key)).cloneReadOnly();
        return validKeys.'map(key => authorTable.get(key));
    }
};