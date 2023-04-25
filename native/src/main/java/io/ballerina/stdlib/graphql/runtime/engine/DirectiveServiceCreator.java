package io.ballerina.stdlib.graphql.runtime.engine;


import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.types.ServiceType;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BTypedesc;

import java.util.Arrays;
import java.util.Optional;

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
//        MethodType initMethod = methodType.get();
//        Parameter[] parameters = initMethod.getParameters();
        return ValueCreator.createObjectValue(serviceType.getPackage(), serviceType.getName());
    }
}
