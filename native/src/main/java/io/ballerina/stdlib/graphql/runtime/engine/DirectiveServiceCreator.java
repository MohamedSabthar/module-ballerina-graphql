package io.ballerina.stdlib.graphql.runtime.engine;


import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.PredefinedTypes;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.types.RemoteMethodType;
import io.ballerina.runtime.api.types.ServiceType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BTypedesc;

import java.util.Arrays;
import java.util.Optional;

import static io.ballerina.stdlib.graphql.runtime.engine.Engine.getRemoteMethod;
import static io.ballerina.stdlib.graphql.runtime.utils.Utils.INTERCEPTOR_EXECUTION_STRAND;

/**
 * This class is used to create the directive service from the type desc.
 */
public class DirectiveServiceCreator {

    public static BObject createDirectiveService(BTypedesc serviceTypeDesc, BObject directiveNode) {
        ServiceType serviceType = (ServiceType) serviceTypeDesc.getDescribingType();
        // TODO: find a way to obtain init method
        Optional<MethodType> methodType = Arrays.stream(serviceType.getMethods())
                .filter(method -> method.getName().equals("init")).findFirst();
        if (methodType.isEmpty()) {
            return ValueCreator.createObjectValue(serviceType.getPackage(), serviceType.getName());
        }
        // MethodType initMethod = methodType.get();
        // Parameter[] parameters = initMethod.getParameters();
        return ValueCreator.createObjectValue(serviceType.getPackage(), serviceType.getName());
    }

    public static Object executeDirective(Environment environment, BObject directiveService, BObject field,
                                          BObject context, BString methodName) {
        Future future = environment.markAsync();
        ExecutionCallback executionCallback = new ExecutionCallback(future);
        ServiceType serviceType = (ServiceType) directiveService.getType();
        RemoteMethodType remoteMethod = getRemoteMethod(serviceType, methodName.getValue());
        Type returnType = TypeCreator.createUnionType(PredefinedTypes.TYPE_ANY, PredefinedTypes.TYPE_NULL);
        if (remoteMethod != null) {
            Object[] arguments = getDirectiveMethodArguments(context, field);
            if (serviceType.isIsolated() && serviceType.isIsolated(remoteMethod.getName())) {
                environment.getRuntime().invokeMethodAsyncConcurrently(directiveService, remoteMethod.getName(), null,
                                                                       INTERCEPTOR_EXECUTION_STRAND, executionCallback,
                                                                       null, returnType, arguments);
            } else {
                environment.getRuntime().invokeMethodAsyncSequentially(directiveService, remoteMethod.getName(), null,
                                                                       INTERCEPTOR_EXECUTION_STRAND, executionCallback,
                                                                       null, returnType, arguments);
            }
        }
        return null;
    }

    private static Object[] getDirectiveMethodArguments(BObject context, BObject field) {
        Object[] args = new Object[4];
        args[0] = context;
        args[1] = true;
        args[2] = field;
        args[3] = true;
        return args;
    }
}
