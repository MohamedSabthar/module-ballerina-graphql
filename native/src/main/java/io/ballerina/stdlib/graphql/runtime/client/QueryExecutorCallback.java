/*
 * Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.sabtharm.stdlib.graphql.runtime.client;

import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.async.Callback;
import io.ballerina.runtime.api.values.BError;

/**
 * This class implements async callback methods of {@link QueryExecutor}.
 */
public class QueryExecutorCallback implements Callback {
    private final Future balFuture;

    public QueryExecutorCallback(Future balFuture) {
        this.balFuture = balFuture;
    }

    @Override
    public void notifySuccess(Object result) {
        balFuture.complete(result);
    }

    @Override
    public void notifyFailure(BError bError) {
        balFuture.complete(bError);
    }
}
