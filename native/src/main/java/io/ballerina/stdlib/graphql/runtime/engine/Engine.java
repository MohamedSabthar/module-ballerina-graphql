/*
 * Copyright (c) 2020, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.graphql.runtime.engine;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.PredefinedTypes;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.types.ObjectType;
import io.ballerina.runtime.api.types.RemoteMethodType;
import io.ballerina.runtime.api.types.ResourceMethodType;
import io.ballerina.runtime.api.types.ServiceType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.UnionType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BFunctionPointer;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.stdlib.graphql.commons.types.Schema;
import io.ballerina.stdlib.graphql.runtime.exception.ConstraintValidationException;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;

import static io.ballerina.runtime.api.TypeTags.SERVICE_TAG;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.COLON;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.GET_ACCESSOR;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.INTERCEPTOR_EXECUTE;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.NAME_FIELD;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.OPERATION_QUERY;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.OPERATION_SUBSCRIPTION;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.RESOURCE_CONFIG;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.SUBSCRIBE_ACCESSOR;
import static io.ballerina.stdlib.graphql.runtime.engine.EngineUtils.isPathsMatching;
import static io.ballerina.stdlib.graphql.runtime.utils.ModuleUtils.getModule;
import static io.ballerina.stdlib.graphql.runtime.utils.Utils.ERROR_TYPE;
import static io.ballerina.stdlib.graphql.runtime.utils.Utils.INTERCEPTOR_EXECUTION_STRAND;
import static io.ballerina.stdlib.graphql.runtime.utils.Utils.INTERNAL_NODE;
import static io.ballerina.stdlib.graphql.runtime.utils.Utils.REMOTE_EXECUTION_STRAND;
import static io.ballerina.stdlib.graphql.runtime.utils.Utils.RESOURCE_EXECUTION_STRAND;
import static io.ballerina.stdlib.graphql.runtime.utils.Utils.createError;

/**
 * This handles Ballerina GraphQL Engine.
 */
public class Engine {

    private static final String SUB_MODULE_NAME_SEPARATOR = ".";
    private static final String DATA_LOADER_SUB_MODULE_NAME = "dataloader";
    private static final String LOADER_ANNOTATION_NAME = "Loader";
    private static final BString BATCH_FUNCTIONS_FIELD = StringUtils.fromString("batchFunctions");

    private Engine() {
    }

    public static Object createSchema(BString schemaString) {
        try {
            Schema schema = getDecodedSchema(schemaString);
            SchemaRecordGenerator schemaRecordGenerator = new SchemaRecordGenerator(schema);
            return schemaRecordGenerator.getSchemaRecord();
        } catch (BError e) {
            return createError("Error occurred while creating the schema", ERROR_TYPE, e);
        } catch (NullPointerException e) {
            return createError("Failed to generate schema", ERROR_TYPE);
        }
    }

    public static Schema getDecodedSchema(BString schemaBString) {
        if (schemaBString == null) {
            throw createError("Schema generation failed due to null schema string", ERROR_TYPE);
        }
        if (schemaBString.getValue().isBlank() || schemaBString.getValue().isEmpty()) {
            throw createError("Schema generation failed due to empty schema string", ERROR_TYPE);
        }
        String schemaString = schemaBString.getValue();
        byte[] decodedString = Base64.getDecoder().decode(schemaString.getBytes(StandardCharsets.UTF_8));
        try {
            ByteArrayInputStream byteStream = new ByteArrayInputStream(decodedString);
            ObjectInputStream inputStream = new ObjectInputStream(byteStream);
            return (Schema) inputStream.readObject();
        } catch (IOException | ClassNotFoundException e) {
            BError cause = ErrorCreator.createError(StringUtils.fromString(e.getMessage()));
            throw createError("Schema generation failed due to exception", ERROR_TYPE, cause);
        }
    }

    public static Object executeSubscriptionResource(Environment environment, BObject context, BObject service,
                                                     BObject fieldObject, BObject responseGenerator,
                                                     boolean validation) {
        BString fieldName = fieldObject.getObjectValue(INTERNAL_NODE).getStringValue(NAME_FIELD);
        ServiceType serviceType = (ServiceType) TypeUtils.getType(service);
        for (ResourceMethodType resourceMethod : serviceType.getResourceMethods()) {
            if (SUBSCRIBE_ACCESSOR.equals(resourceMethod.getAccessor()) &&
                    fieldName.getValue().equals(resourceMethod.getResourcePath()[0])) {
                ArgumentHandler argumentHandler = new ArgumentHandler(resourceMethod, context, fieldObject,
                                                                      responseGenerator, service, validation);
                try {
                    argumentHandler.validateInputConstraint(environment);
                } catch (ConstraintValidationException e) {
                    return null;
                }
                Future subscriptionFutureResult = environment.markAsync();
                ExecutionCallback executionCallback = new ExecutionCallback(subscriptionFutureResult);
                Object[] args = argumentHandler.getArguments();
                ObjectType objectType = (ObjectType) TypeUtils.getReferredType(TypeUtils.getType(service));
                UnionType typeUnion =
                        TypeCreator.createUnionType(PredefinedTypes.TYPE_STREAM, PredefinedTypes.TYPE_ERROR);
                if (objectType.isIsolated() && objectType.isIsolated(resourceMethod.getName())) {
                    environment.getRuntime()
                            .invokeMethodAsyncConcurrently(service, resourceMethod.getName(), null,
                                    null, executionCallback, null, typeUnion, args);
                } else {
                    environment.getRuntime()
                            .invokeMethodAsyncSequentially(service, resourceMethod.getName(), null,
                                    null, executionCallback, null, typeUnion, args);
                }
                return null;
            }
        }
        return null;
    }

    public static Object executeQueryResource(Environment environment, BObject context, BObject service,
                                              ResourceMethodType resourceMethod, BObject fieldObject,
                                              BObject responseGenerator, boolean validation) {
        if (resourceMethod == null) {
            return null;
        }
        ArgumentHandler argumentHandler = new ArgumentHandler(resourceMethod, context, fieldObject, responseGenerator,
                                                              service, validation);
        try {
            argumentHandler.validateInputConstraint(environment);
        } catch (ConstraintValidationException e) {
            return null;
        }
        Future future = environment.markAsync();
        ExecutionCallback executionCallback = new ExecutionCallback(future);
        ServiceType serviceType = (ServiceType) TypeUtils.getType(service);
        Type returnType = TypeCreator.createUnionType(PredefinedTypes.TYPE_ANY, PredefinedTypes.TYPE_NULL);
        Object[] arguments = argumentHandler.getArguments();
        if (serviceType.isIsolated() && serviceType.isIsolated(resourceMethod.getName())) {
            environment.getRuntime().invokeMethodAsyncConcurrently(service, resourceMethod.getName(), null,
                    RESOURCE_EXECUTION_STRAND, executionCallback,
                    null, returnType, arguments);
        } else {
            environment.getRuntime().invokeMethodAsyncSequentially(service, resourceMethod.getName(), null,
                    RESOURCE_EXECUTION_STRAND, executionCallback,
                    null, returnType, arguments);
        }
        return null;
    }

    public static Object executeMutationMethod(Environment environment, BObject context, BObject service,
                                               BObject fieldObject, BObject responseGenerator, boolean validation) {
        ServiceType serviceType = (ServiceType) TypeUtils.getType(service);
        String fieldName = fieldObject.getObjectValue(INTERNAL_NODE).getStringValue(NAME_FIELD).getValue();
        for (RemoteMethodType remoteMethod : serviceType.getRemoteMethods()) {
            if (remoteMethod.getName().equals(fieldName)) {
                ArgumentHandler argumentHandler = new ArgumentHandler(remoteMethod, context, fieldObject,
                                                                      responseGenerator, service, validation);
                try {
                    argumentHandler.validateInputConstraint(environment);
                } catch (ConstraintValidationException e) {
                    return null;
                }
                Future future = environment.markAsync();
                ExecutionCallback executionCallback = new ExecutionCallback(future);
                Type returnType = TypeCreator.createUnionType(PredefinedTypes.TYPE_ANY, PredefinedTypes.TYPE_NULL);
                Object[] arguments = argumentHandler.getArguments();
                if (serviceType.isIsolated() && serviceType.isIsolated(remoteMethod.getName())) {
                    environment.getRuntime().invokeMethodAsyncConcurrently(service, remoteMethod.getName(), null,
                            REMOTE_EXECUTION_STRAND, executionCallback,
                            null, returnType, arguments);
                } else {
                    environment.getRuntime().invokeMethodAsyncSequentially(service, remoteMethod.getName(), null,
                            REMOTE_EXECUTION_STRAND, executionCallback,
                            null, returnType, arguments);
                }
                return null;
            }
        }
        return null;
    }

    public static Object executeInterceptor(Environment environment, BObject interceptor, BObject field,
                                            BObject context) {
        ServiceType serviceType = (ServiceType) TypeUtils.getType(interceptor);
        RemoteMethodType remoteMethod = getRemoteMethod(serviceType, INTERCEPTOR_EXECUTE);
        if (remoteMethod == null) {
            return null;
        }
        Future future = environment.markAsync();
        ExecutionCallback executionCallback = new ExecutionCallback(future);
        Type returnType = TypeCreator.createUnionType(PredefinedTypes.TYPE_ANY, PredefinedTypes.TYPE_NULL);
        Object[] arguments = getInterceptorArguments(context, field);
        if (serviceType.isIsolated() && serviceType.isIsolated(remoteMethod.getName())) {
            environment.getRuntime().invokeMethodAsyncConcurrently(interceptor, remoteMethod.getName(), null,
                                                                   INTERCEPTOR_EXECUTION_STRAND, executionCallback,
                                                                   null, returnType, arguments);
        } else {
            environment.getRuntime().invokeMethodAsyncSequentially(interceptor, remoteMethod.getName(), null,
                                                                   INTERCEPTOR_EXECUTION_STRAND, executionCallback,
                                                                   null, returnType, arguments);
        }
        return null;
    }

    public static Object getResourceMethod(BObject service, BArray path) {
        ServiceType serviceType = (ServiceType) TypeUtils.getType(service);
        List<String> pathList = getPathList(path);
        return getResourceMethod(serviceType, pathList, GET_ACCESSOR);
    }

    public static Object getRemoteMethod(BObject service, BString methodName) {
        ServiceType serviceType = (ServiceType) TypeUtils.getType(service);
        return getRemoteMethod(serviceType, methodName.getValue());
    }

    private static ResourceMethodType getResourceMethod(ServiceType serviceType, List<String> path, String accessor) {
        for (ResourceMethodType resourceMethod : serviceType.getResourceMethods()) {
            if (accessor.equals(resourceMethod.getAccessor()) && isPathsMatching(resourceMethod, path)) {
                return resourceMethod;
            }
        }
        return null;
    }

    private static List<String> getPathList(BArray pathArray) {
        List<String> result = new ArrayList<>();
        for (int i = 0; i < pathArray.size(); i++) {
            BString pathSegment = (BString) pathArray.get(i);
            result.add(pathSegment.getValue());
        }
        return result;
    }

    private static RemoteMethodType getRemoteMethod(ServiceType serviceType, String methodName) {
        for (RemoteMethodType remoteMethod : serviceType.getRemoteMethods()) {
            if (remoteMethod.getName().equals(methodName)) {
                return remoteMethod;
            }
        }
        return null;
    }

    private static Object[] getInterceptorArguments(BObject context, BObject field) {
        Object[] args = new Object[4];
        args[0] = context;
        args[1] = true;
        args[2] = field;
        args[3] = true;
        return args;
    }

    public static BString getInterceptorName(BObject interceptor) {
        ServiceType serviceType = (ServiceType) TypeUtils.getType(interceptor);
        return StringUtils.fromString(serviceType.getName());
    }

    public static Object getResourceAnnotation(BObject service, BString operationType, BArray path,
                                               BString methodName) {
        ServiceType serviceType = (ServiceType) TypeUtils.getType(service);
        MethodType methodType = null;
        if (OPERATION_QUERY.equals(operationType.getValue())) {
            methodType = getResourceMethod(serviceType, getPathList(path), GET_ACCESSOR);
        } else if (OPERATION_SUBSCRIPTION.equals(operationType.getValue())) {
            methodType = getResourceMethod(serviceType, getPathList(path), SUBSCRIBE_ACCESSOR);
        } else {
            methodType = getRemoteMethod(serviceType, String.valueOf(methodName));
        }
        if (methodType != null) {
            BString identifier = StringUtils.fromString(getModule().toString() + COLON + RESOURCE_CONFIG);
            return methodType.getAnnotation(identifier);
        }
        return null;
    }

    public static boolean hasLoadMethod(BObject serviceObject, BString resourceMethodName, boolean isRemoteMethod) {
        Type serviceType = serviceObject.getOriginalType();
        if (serviceType.getTag() != SERVICE_TAG) {
            return false;
        }
        ServiceType rootServiceType = (ServiceType) serviceType;
        if (isRemoteMethod) {
            return Arrays.stream(rootServiceType.getRemoteMethods()).anyMatch(
                    methodType -> methodType.getName().equals(resourceMethodName.getValue())
                            && getLoadAnnotation(methodType) != null);
        }
        return Arrays.stream(rootServiceType.getResourceMethods()).anyMatch(
                methodType -> methodType.getResourcePath()[0].equals(resourceMethodName.getValue())
                        && getLoadAnnotation(methodType) != null);
    }

    private static BMap<BString, Object> getLoadAnnotation(MethodType methodType) {
        String dataLoaderModuleName = getDataLoaderSubModuleName();
        return (BMap<BString, Object>) methodType.getAnnotation(StringUtils.fromString(dataLoaderModuleName));
    }

    private static String getDataLoaderSubModuleName() {
        String graphqlModuleName = getModule().toString();
        String[] tokens = graphqlModuleName.split(COLON);
        String dataLoaderModuleName = tokens[0] + SUB_MODULE_NAME_SEPARATOR + DATA_LOADER_SUB_MODULE_NAME + COLON;
        if (tokens.length == 2) {
            dataLoaderModuleName += tokens[1];
        }
        return dataLoaderModuleName + COLON + LOADER_ANNOTATION_NAME;
    }

    public static BMap<BString, BFunctionPointer> getBatchFunctionsMap(BObject serviceObject, BString loadMethodName,
                                                                       boolean loadMethodIsRemote) {
        ServiceType serviceType = (ServiceType) serviceObject.getOriginalType();
        MethodType loadMethodType = loadMethodIsRemote ? getRemoteMethod(serviceType, loadMethodName.getValue()) :
                getResourceMethod(serviceType, List.of(loadMethodName.getValue()), GET_ACCESSOR);
        BMap<BString, Object> loadAnnotation = getLoadAnnotation(loadMethodType);
        return (BMap<BString, BFunctionPointer>) loadAnnotation.get(BATCH_FUNCTIONS_FIELD);
    }

    public static void executeLoadMethod(Environment environment, BObject context, BObject service,
                                         MethodType resourceMethod, BObject fieldObject) {
        Future future = environment.markAsync();
        ExecutionCallback executionCallback = new ExecutionCallback(future);
        ServiceType serviceType = (ServiceType) TypeUtils.getType(service);
        ArgumentHandler argumentHandler = new ArgumentHandler(resourceMethod, context, fieldObject, null, service,
                                                              false);
        Object[] arguments = argumentHandler.getArguments();
        if (serviceType.isIsolated() && serviceType.isIsolated(resourceMethod.getName())) {
            environment.getRuntime()
                    .invokeMethodAsyncConcurrently(service, resourceMethod.getName(), null, RESOURCE_EXECUTION_STRAND,
                                                   executionCallback, null, null, arguments);
        } else {
            environment.getRuntime()
                    .invokeMethodAsyncSequentially(service, resourceMethod.getName(), null, RESOURCE_EXECUTION_STRAND,
                                                   executionCallback, null, null, arguments);
        }
    }
}
