package io.ballerina.stdlib.graphql.runtime.utils;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.async.Callback;
import io.ballerina.runtime.api.types.ObjectType;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BTypedesc;

import static io.ballerina.runtime.api.PredefinedTypes.TYPE_ANYDATA;

/**
 * Utility functions for the graphql DataLoader.
 */
public class DataLoaderUtils {
    private static final String DATA_LOADER_PROCESSES_GET_METHOD_NAME = "processGet";

    private DataLoaderUtils() {
    }

    public static Object get(Environment env, BObject dataLoader, Object key, BTypedesc typedesc) {
        Future balFuture = env.markAsync();
        ObjectType clientType = (ObjectType) TypeUtils.getReferredType(TypeUtils.getType(dataLoader));
        Object[] paramFeed = getProcessGetMethodParams(key, typedesc);
        Callback executionCallback = new DataLoaderExecutionCallback(balFuture);
        if (clientType.isIsolated() && clientType.isIsolated(DATA_LOADER_PROCESSES_GET_METHOD_NAME)) {
            env.getRuntime()
                    .invokeMethodAsyncConcurrently(dataLoader, DATA_LOADER_PROCESSES_GET_METHOD_NAME, null, null,
                                                   executionCallback, null, TYPE_ANYDATA, paramFeed);
            return null;
        }
        env.getRuntime().invokeMethodAsyncSequentially(dataLoader, DATA_LOADER_PROCESSES_GET_METHOD_NAME, null, null,
                                                       executionCallback, null, TYPE_ANYDATA, paramFeed);
        return null;
    }

    private static Object[] getProcessGetMethodParams(Object key, BTypedesc typedesc) {
        Object[] paramFeed = new Object[4];
        paramFeed[0] = key;
        paramFeed[1] = true;
        paramFeed[2] = typedesc;
        paramFeed[3] = true;
        return paramFeed;
    }
}
