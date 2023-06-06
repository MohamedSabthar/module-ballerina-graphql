package io.ballerina.stdlib.graphql.runtime.utils;

import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.async.Callback;
import io.ballerina.runtime.api.values.BError;

/**
 * Callback class for executing DataLoader dependently typed methods.
 */
public class DataLoaderExecutionCallback implements Callback {
    private final Future future;

    DataLoaderExecutionCallback(Future future) {
        this.future = future;
    }

    @Override
    public void notifySuccess(Object o) {
        this.future.complete(o);
    }

    @Override
    public void notifyFailure(BError bError) {
        bError.printStackTrace();
        // Service level `panic` is captured in this method.
        // Since, `panic` is due to a critical application bug or resource exhaustion we need to exit the application.
        // Please refer: https://github.com/ballerina-platform/ballerina-standard-library/issues/2714
        System.exit(1);
    }
}
