package io.ballerina.stdlib.graphql.compiler.schema.generator;

import io.ballerina.compiler.api.symbols.ArrayTypeSymbol;
import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.ConstantSymbol;
import io.ballerina.compiler.api.symbols.EnumSymbol;
import io.ballerina.compiler.api.symbols.IntersectionTypeSymbol;
import io.ballerina.compiler.api.symbols.MapTypeSymbol;
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ObjectTypeSymbol;
import io.ballerina.compiler.api.symbols.ParameterKind;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.RecordFieldSymbol;
import io.ballerina.compiler.api.symbols.RecordTypeSymbol;
import io.ballerina.compiler.api.symbols.ResourceMethodSymbol;
import io.ballerina.compiler.api.symbols.StreamTypeSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TableTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeDefinitionSymbol;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.compiler.api.symbols.resourcepath.PathSegmentList;
import io.ballerina.compiler.api.symbols.resourcepath.util.PathSegment;
import io.ballerina.projects.Project;
import io.ballerina.stdlib.graphql.commons.types.Description;
import io.ballerina.stdlib.graphql.commons.types.EnumValue;
import io.ballerina.stdlib.graphql.commons.types.Field;
import io.ballerina.stdlib.graphql.commons.types.InputValue;
import io.ballerina.stdlib.graphql.commons.types.ObjectKind;
import io.ballerina.stdlib.graphql.commons.types.Position;
import io.ballerina.stdlib.graphql.commons.types.ScalarType;
import io.ballerina.stdlib.graphql.commons.types.Schema;
import io.ballerina.stdlib.graphql.commons.types.Type;
import io.ballerina.stdlib.graphql.commons.types.TypeKind;
import io.ballerina.stdlib.graphql.commons.types.TypeName;
import io.ballerina.stdlib.graphql.compiler.service.InterfaceEntityFinder;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static io.ballerina.stdlib.graphql.commons.utils.TypeUtils.removeEscapeCharacter;
import static io.ballerina.stdlib.graphql.compiler.Utils.getEffectiveType;
import static io.ballerina.stdlib.graphql.compiler.Utils.getEffectiveTypes;
import static io.ballerina.stdlib.graphql.compiler.Utils.isFileUploadParameter;
import static io.ballerina.stdlib.graphql.compiler.Utils.isResourceMethod;
import static io.ballerina.stdlib.graphql.compiler.Utils.isValidGraphqlParameter;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.MAP_KEY_ARGUMENT_DESCRIPTION;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.MAP_KEY_ARGUMENT_NAME;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.getDeprecationReason;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.getDescription;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.getTypeName;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.getTypePosition;
import static io.ballerina.stdlib.graphql.compiler.schema.generator.GeneratorUtils.getWrapperType;

/**
 * Generates the GraphQL Types and InputTypes from a given, valid, Ballerina symbol.
 */
public class TypeCreator {
    private static final String DEFAULT_VALUE = "\"\"";

    private final InterfaceEntityFinder interfaceEntityFinder;
    private final Schema schema;
    private final Project project;
    private final List<Type> visitedInterfaces;

    public TypeCreator(InterfaceEntityFinder interfaceEntityFinder, Schema schema, Project project) {
        this.interfaceEntityFinder = interfaceEntityFinder;
        this.schema = schema;
        this.project = project;
        this.visitedInterfaces = new ArrayList<>();
    }

    private static boolean isNilable(TypeSymbol typeSymbol) {
        if (typeSymbol.typeKind() != TypeDescKind.UNION) {
            return false;
        }
        UnionTypeSymbol unionTypeSymbol = (UnionTypeSymbol) typeSymbol;
        for (TypeSymbol memberType : unionTypeSymbol.memberTypeDescriptors()) {
            if (memberType.typeKind() == TypeDescKind.NIL) {
                return true;
            }
        }
        return false;
    }

    private static String getParameterDescription(String parameterName, MethodSymbol methodSymbol) {
        if (methodSymbol.documentation().isEmpty()) {
            return null;
        }
        return methodSymbol.documentation().get().parameterMap().get(parameterName);
    }

    Field getField(ResourceMethodSymbol methodSymbol) {
        return getField(methodSymbol, ((PathSegmentList) methodSymbol.resourcePath()).list());
    }

    Field getField(ResourceMethodSymbol methodSymbol, List<PathSegment> list) {
        if (list.size() == 1) {
            boolean isDeprecated = methodSymbol.deprecated();
            String deprecationReason = getDeprecationReason(methodSymbol);
            Type fieldType = getType(methodSymbol);
            Position position = getTypePosition(methodSymbol.getLocation(), methodSymbol, this.project);
            Field field = new Field(list.get(0).signature(), getDescription(methodSymbol), fieldType, isDeprecated,
                                    deprecationReason, position);
            addArgs(field, methodSymbol);
            return field;
        } else {
            PathSegment pathSegment = list.get(0);
            Type type = getType(methodSymbol, pathSegment, list);
            return new Field(pathSegment.signature(), getWrapperType(type, TypeKind.NON_NULL));
        }
    }

    private Type getType(ResourceMethodSymbol methodSymbol, PathSegment pathSegment, List<PathSegment> list) {
        Type type = addType(pathSegment.signature(), TypeKind.OBJECT, Description.GENERATED_TYPE.getDescription());
        List<PathSegment> remainingPathList = list.subList(1, list.size());
        type.addField(getField(methodSymbol, remainingPathList));
        return type;
    }

    Field getField(MethodSymbol methodSymbol) {
        boolean isDeprecated = methodSymbol.deprecated();
        String deprecationReason = getDeprecationReason(methodSymbol);
        if (methodSymbol.getName().isEmpty()) {
            return null;
        }
        Type fieldType = getType(methodSymbol);
        Position position = getTypePosition(methodSymbol.getLocation(), methodSymbol, this.project);
        Field field = new Field(methodSymbol.getName().get(), getDescription(methodSymbol), fieldType, isDeprecated,
                                deprecationReason, position);
        addArgs(field, methodSymbol);
        return field;
    }

    private void addArgs(Field field, MethodSymbol methodSymbol) {
        if (methodSymbol.typeDescriptor().params().isEmpty()) {
            return;
        }
        for (ParameterSymbol parameterSymbol : methodSymbol.typeDescriptor().params().get()) {
            if (isValidGraphqlParameter(parameterSymbol.typeDescriptor()) || parameterSymbol.getName().isEmpty()) {
                continue;
            }
            String parameterName = parameterSymbol.getName().get();
            String description = getParameterDescription(parameterName, methodSymbol);
            field.addArg(getArg(parameterName, description, parameterSymbol));
        }
    }

    InputValue getArg(String parameterName, String description, ParameterSymbol parameterSymbol) {
        Type type = getInputFieldType(parameterSymbol.typeDescriptor());
        String defaultValue = getDefaultValue(parameterSymbol);
        return new InputValue(parameterName, type, description, defaultValue);
    }

    private Type getType(MethodSymbol methodSymbol) {
        if (methodSymbol.typeDescriptor().returnTypeDescriptor().isEmpty()) {
            return null;
        }
        TypeSymbol typeSymbol = methodSymbol.typeDescriptor().returnTypeDescriptor().get();
        return getFieldType(typeSymbol);
    }

    private Type getType(TypeSymbol typeSymbol) {
        String typeName = getTypeName(typeSymbol);
        if (this.schema.containsType(typeName)) {
            return this.schema.getType(typeName);
        }
        switch (typeSymbol.typeKind()) {
            case STRING:
            case STRING_CHAR:
                return addType(ScalarType.STRING);
            case INT:
                return addType(ScalarType.INT);
            case FLOAT:
                return addType(ScalarType.FLOAT);
            case BOOLEAN:
                return addType(ScalarType.BOOLEAN);
            case DECIMAL:
                return addType(ScalarType.DECIMAL);
            case TYPE_REFERENCE:
                return getType((TypeReferenceTypeSymbol) typeSymbol, typeName);
            case ARRAY:
                return getType((ArrayTypeSymbol) typeSymbol);
            case UNION:
                return getType(typeName, null, null, (UnionTypeSymbol) typeSymbol);
            case INTERSECTION:
                return getType(null, null, null, null, (IntersectionTypeSymbol) typeSymbol);
            case STREAM:
                return getType(((StreamTypeSymbol) typeSymbol).typeParameter());
            case TABLE:
                return getType((TableTypeSymbol) typeSymbol);
        }
        return null;
    }

    Type addType(ScalarType scalarType) {
        return this.schema.addType(scalarType);
    }

    Type addType(TypeName typeName) {
        return addType(typeName.getName(), TypeKind.OBJECT, null);
    }

    private Type addType(String name, TypeKind kind, String description) {
        return this.schema.addType(name, kind, description);
    }

    private Type addType(String name, TypeKind kind, String description, Position position) {
        return this.schema.addType(name, kind, description, position);
    }

    private Type addType(String name, TypeKind kind, String description, Position position, ObjectKind objectKind) {
        return this.schema.addType(name, kind, description, position, objectKind);
    }

    private Type getType(TypeReferenceTypeSymbol typeSymbol, String name) {
        if (typeSymbol.getName().isEmpty()) {
            return null;
        }
        Symbol definitionSymbol = typeSymbol.definition();
        if (definitionSymbol.kind() == SymbolKind.TYPE_DEFINITION) {
            return getType(name, (TypeDefinitionSymbol) definitionSymbol);
        } else if (definitionSymbol.kind() == SymbolKind.CLASS) {
            return getType(name, (ClassSymbol) definitionSymbol);
        } else if (definitionSymbol.kind() == SymbolKind.ENUM) {
            return getType(name, (EnumSymbol) definitionSymbol);
        }
        return null;
    }

    private Type getType(ArrayTypeSymbol arrayTypeSymbol) {
        TypeSymbol memberTypeSymbol = arrayTypeSymbol.memberTypeDescriptor();
        return getWrapperType(getFieldType(memberTypeSymbol), TypeKind.LIST);
    }

    Type getType(String name, TypeDefinitionSymbol typeDefinitionSymbol) {
        String description = getDescription(typeDefinitionSymbol);
        Map<String, String> parameterMap;
        if (typeDefinitionSymbol.documentation().isEmpty()) {
            parameterMap = new HashMap<>();
        } else {
            parameterMap = typeDefinitionSymbol.documentation().get().parameterMap();
        }
        if (typeDefinitionSymbol.typeDescriptor().typeKind() == TypeDescKind.RECORD) {
            Position position = getTypePosition(typeDefinitionSymbol.getLocation(), typeDefinitionSymbol, this.project);
            RecordTypeSymbol recordType = (RecordTypeSymbol) typeDefinitionSymbol.typeDescriptor();
            return getType(name, description, position, parameterMap, recordType);
        } else if (typeDefinitionSymbol.typeDescriptor().typeKind() == TypeDescKind.UNION) {
            Position position = getTypePosition(typeDefinitionSymbol.getLocation(), typeDefinitionSymbol, this.project);
            return getType(name, description, position, (UnionTypeSymbol) typeDefinitionSymbol.typeDescriptor());
        } else if (typeDefinitionSymbol.typeDescriptor().typeKind() == TypeDescKind.INTERSECTION) {
            IntersectionTypeSymbol intersectionType = (IntersectionTypeSymbol) typeDefinitionSymbol.typeDescriptor();
            Position position = getTypePosition(typeDefinitionSymbol.getLocation(), typeDefinitionSymbol, this.project);
            return getType(name, description, position, parameterMap, intersectionType);
        } else if (typeDefinitionSymbol.typeDescriptor().typeKind() == TypeDescKind.TABLE) {
            return getType((TableTypeSymbol) typeDefinitionSymbol.typeDescriptor());
        } else if (typeDefinitionSymbol.typeDescriptor().typeKind() == TypeDescKind.OBJECT) {
            ObjectTypeSymbol objectTypeSymbol = (ObjectTypeSymbol) typeDefinitionSymbol.typeDescriptor();
            Position position = getTypePosition(typeDefinitionSymbol.getLocation(), typeDefinitionSymbol, this.project);
            return getType(name, description, position, objectTypeSymbol);
        }
        return null;
    }

    Type getType(String name, String description, Position position, ObjectTypeSymbol objectTypeSymbol) {
        Type objectType = addType(name, TypeKind.INTERFACE, description, position);
        getTypesFromInterface(name, objectType);

        for (MethodSymbol methodSymbol : objectTypeSymbol.methods().values()) {
            if (isResourceMethod(methodSymbol)) {
                objectType.addField(getField((ResourceMethodSymbol) methodSymbol));
            }
        }
        return objectType;
    }

    Type getType(String name, ClassSymbol classSymbol) {
        String description = getDescription(classSymbol);
        Position position = getTypePosition(classSymbol.getLocation(), classSymbol, this.project);
        Type objectType = addType(name, TypeKind.OBJECT, description, position, ObjectKind.CLASS);

        for (MethodSymbol methodSymbol : classSymbol.methods().values()) {
            if (isResourceMethod(methodSymbol)) {
                objectType.addField(getField((ResourceMethodSymbol) methodSymbol));
            }
        }
        return objectType;
    }

    private void getTypesFromInterface(String typeName, Type interfaceType) {
        // Implementations can only contain class symbols or object type definitions
        List<Symbol> implementations = this.interfaceEntityFinder.getImplementations(typeName);
        visitedInterfaces.add(interfaceType);
        for (Symbol implementation : implementations) {
            Type implementedType;
            // When adding an implementation, the name is already checked. Therefore, no need to check isEmpty().
            // noinspection OptionalGetWithoutIsPresent
            String implementationName = implementation.getName().get();
            if (implementation.kind() == SymbolKind.CLASS) {
                implementedType = getType(implementationName, (ClassSymbol) implementation);
            } else {
                TypeDefinitionSymbol typeDefinitionSymbol = (TypeDefinitionSymbol) implementation;
                String description = getDescription(typeDefinitionSymbol);
                ObjectTypeSymbol objectTypeSymbol = (ObjectTypeSymbol) typeDefinitionSymbol.typeDescriptor();
                Position position = getTypePosition(typeDefinitionSymbol.getLocation(), typeDefinitionSymbol,
                                                    this.project);
                implementedType = getType(implementationName, description, position, objectTypeSymbol);
            }

            interfaceType.addPossibleType(implementedType);
            addTransitiveImplementationsToInterface(interfaceType, implementedType);
            addSuperInterfacesToImplementation(implementedType);
        }
        visitedInterfaces.remove(interfaceType);
    }

    private void addTransitiveImplementationsToInterface(Type interfaceType, Type implementedType) {
        if (implementedType.getPossibleTypes() == null) {
            return;
        }
        for (Type transitiveImplementation : implementedType.getPossibleTypes()) {
            interfaceType.addPossibleType(transitiveImplementation);
        }
    }

    private void addSuperInterfacesToImplementation(Type implementedType) {
        for (Type superInterface : visitedInterfaces) {
            implementedType.addInterface(superInterface);
        }
    }

    private Type getType(String name, EnumSymbol enumSymbol) {
        String description = getDescription(enumSymbol);
        Position position = getTypePosition(enumSymbol.getLocation(), enumSymbol, this.project);
        Type enumType = addType(name, TypeKind.ENUM, description, position);
        for (ConstantSymbol enumMember : enumSymbol.members()) {
            addEnumValueToType(enumType, enumMember);
        }
        return enumType;
    }

    private Type getType(String name, String description, Position position, Map<String, String> fieldMap,
                         RecordTypeSymbol recordTypeSymbol) {
        Type objectType = addType(name, TypeKind.OBJECT, description, position, ObjectKind.RECORD);
        for (RecordFieldSymbol recordFieldSymbol : recordTypeSymbol.fieldDescriptors().values()) {
            if (recordFieldSymbol.getName().isEmpty()) {
                continue;
            }
            String fieldDescription = fieldMap.get(removeEscapeCharacter(recordFieldSymbol.getName().get()));
            objectType.addField(getField(recordFieldSymbol, fieldDescription));
        }
        return objectType;
    }

    private Field getField(RecordFieldSymbol recordFieldSymbol, String description) {
        if (recordFieldSymbol.getName().isEmpty()) {
            return null;
        }
        String name = recordFieldSymbol.getName().get();
        Field field = new Field(name, description);
        TypeSymbol typeSymbol = recordFieldSymbol.typeDescriptor();
        Type type;
        if (typeSymbol.typeKind() == TypeDescKind.MAP) {
            type = getType(((MapTypeSymbol) typeSymbol).typeParam());
            Type argType = getWrapperType(addType(ScalarType.STRING), TypeKind.NON_NULL);
            field.addArg(new InputValue(MAP_KEY_ARGUMENT_NAME, argType, MAP_KEY_ARGUMENT_DESCRIPTION, null));
        } else {
            type = getType(typeSymbol);
        }
        if (!isNilable(typeSymbol) && !recordFieldSymbol.isOptional()) {
            type = getWrapperType(type, TypeKind.NON_NULL);
        }
        field.setType(type);
        return field;
    }

    private Type getType(String name, String description, Position position, UnionTypeSymbol unionTypeSymbol) {
        List<TypeSymbol> effectiveTypes = getEffectiveTypes(unionTypeSymbol);
        if (effectiveTypes.size() == 1) {
            return getType(effectiveTypes.get(0));
        }

        String typeName = name == null ? getTypeName(effectiveTypes) : name;
        String typeDescription = description == null ? Description.GENERATED_UNION_TYPE.getDescription() : description;
        Type unionType = addType(typeName, TypeKind.UNION, typeDescription, position);

        for (TypeSymbol typeSymbol : effectiveTypes) {
            Type possibleType = getType(typeSymbol);
            String memberTypeName = getTypeName(typeSymbol);
            if (memberTypeName == null) {
                continue;
            }
            unionType.addPossibleType(possibleType);
        }
        return unionType;
    }

    private Type getType(String name, String description, Position position, Map<String, String> parameterMap,
                         IntersectionTypeSymbol intersectionTypeSymbol) {
        TypeSymbol effectiveType = getEffectiveType(intersectionTypeSymbol);
        if (name == null) {
            return getType(effectiveType);
        } else {
            if (parameterMap == null) {
                parameterMap = new HashMap<>();
            }
            return getType(name, description, position, parameterMap, (RecordTypeSymbol) effectiveType);
        }
    }

    private Type getType(TableTypeSymbol tableTypeSymbol) {
        TypeSymbol typeSymbol = tableTypeSymbol.rowTypeParameter();
        Type type = getType(typeSymbol);
        return getWrapperType(getWrapperType(type, TypeKind.NON_NULL), TypeKind.LIST);
    }

    private Type getInputType(TypeSymbol typeSymbol) {
        String typeName = getTypeName(typeSymbol);
        if (this.schema.containsType(typeName)) {
            return this.schema.getType(typeName);
        }
        switch (typeSymbol.typeKind()) {
            case STRING:
            case STRING_CHAR:
                return addType(ScalarType.STRING);
            case INT:
                return addType(ScalarType.INT);
            case FLOAT:
                return addType(ScalarType.FLOAT);
            case BOOLEAN:
                return addType(ScalarType.BOOLEAN);
            case DECIMAL:
                return addType(ScalarType.DECIMAL);
            case TYPE_REFERENCE:
                return getInputType((TypeReferenceTypeSymbol) typeSymbol, typeName);
            case ARRAY:
                return getInputType((ArrayTypeSymbol) typeSymbol);
            case UNION:
                return getInputType((UnionTypeSymbol) typeSymbol);
            case INTERSECTION:
                return getInputType(null, null, (IntersectionTypeSymbol) typeSymbol, null);
        }
        return null;
    }

    private Type getInputType(TypeReferenceTypeSymbol typeReferenceTypeSymbol, String typeName) {
        if (isFileUploadParameter(typeReferenceTypeSymbol)) {
            return addType(ScalarType.UPLOAD);
        }
        if (typeReferenceTypeSymbol.getName().isEmpty()) {
            return null;
        }
        Symbol definitionSymbol = typeReferenceTypeSymbol.definition();
        if (definitionSymbol.kind() == SymbolKind.TYPE_DEFINITION) {
            return getInputType(typeName, (TypeDefinitionSymbol) definitionSymbol);
        } else if (definitionSymbol.kind() == SymbolKind.ENUM) {
            return getType(typeName, (EnumSymbol) definitionSymbol);
        }
        return null;
    }

    private Type getInputType(ArrayTypeSymbol arrayTypeSymbol) {
        TypeSymbol memberTypeSymbol = arrayTypeSymbol.memberTypeDescriptor();
        return getWrapperType(getInputFieldType(memberTypeSymbol), TypeKind.LIST);
    }

    private Type getInputType(String typeName, TypeDefinitionSymbol typeDefinitionSymbol) {
        TypeSymbol typeDescriptor = typeDefinitionSymbol.typeDescriptor();
        String description = getDescription(typeDefinitionSymbol);
        Position position = getTypePosition(typeDefinitionSymbol.getLocation(), typeDefinitionSymbol, this.project);
        switch (typeDescriptor.typeKind()) {
            case RECORD:
                return getInputType(typeName, description, (RecordTypeSymbol) typeDescriptor, position);
            case UNION:
                return getInputType((UnionTypeSymbol) typeDescriptor);
            case INTERSECTION:
                return getInputType(typeName, description, (IntersectionTypeSymbol) typeDescriptor, position);
            default:
                return null;
        }
    }

    private Type getInputType(String name, String description, RecordTypeSymbol recordTypeSymbol, Position position) {
        Type objectType = addType(name, TypeKind.INPUT_OBJECT, description, position);
        for (RecordFieldSymbol recordFieldSymbol : recordTypeSymbol.fieldDescriptors().values()) {
            objectType.addInputField(getInputField(recordFieldSymbol));
        }
        return objectType;
    }

    private Type getInputType(UnionTypeSymbol unionTypeSymbol) {
        List<TypeSymbol> effectiveTypes = getEffectiveTypes(unionTypeSymbol);
        for (TypeSymbol typeSymbol : effectiveTypes) {
            return getInputType(typeSymbol);
        }
        return null;
    }

    private Type getInputType(String typeName, String description, IntersectionTypeSymbol intersectionTypeSymbol,
                              Position position) {
        TypeSymbol effectiveType = getEffectiveType(intersectionTypeSymbol);
        if (typeName == null) {
            return getInputType(effectiveType);
        } else {
            return getInputType(typeName, description, (RecordTypeSymbol) effectiveType, position);
        }
    }

    private InputValue getInputField(RecordFieldSymbol recordFieldSymbol) {
        if (recordFieldSymbol.getName().isEmpty()) {
            return null;
        }
        String name = recordFieldSymbol.getName().get();
        String description = getDescription(recordFieldSymbol);
        Type type = getInputType(recordFieldSymbol.typeDescriptor());
        if (!isNilable(recordFieldSymbol.typeDescriptor()) && !recordFieldSymbol.isOptional()) {
            type = getWrapperType(type, TypeKind.NON_NULL);
        }
        String defaultValue = getDefaultValue(recordFieldSymbol);
        return new InputValue(name, type, description, defaultValue);
    }

    private void addEnumValueToType(Type type, ConstantSymbol enumMember) {
        if (enumMember.getName().isEmpty()) {
            return;
        }
        String memberDescription = getDescription(enumMember);
        String name = enumMember.getName().get();
        boolean isDeprecated = enumMember.deprecated();
        String deprecationReason = getDeprecationReason(enumMember);
        EnumValue enumValue = new EnumValue(name, memberDescription, isDeprecated, deprecationReason);
        type.addEnumValue(enumValue);
    }

    private Type getFieldType(TypeSymbol typeSymbol) {
        Type type = getType(typeSymbol);
        if (isNilable(typeSymbol)) {
            return type;
        }
        return getWrapperType(type, TypeKind.NON_NULL);
    }

    private Type getInputFieldType(TypeSymbol typeSymbol) {
        Type type = getInputType(typeSymbol);
        if (isNilable(typeSymbol)) {
            return type;
        }
        return getWrapperType(type, TypeKind.NON_NULL);
    }

    private String getDefaultValue(RecordFieldSymbol recordFieldSymbol) {
        if (recordFieldSymbol.hasDefaultValue()) {
            return DEFAULT_VALUE;
        }
        return null;
    }

    private String getDefaultValue(ParameterSymbol parameterSymbol) {
        if (parameterSymbol.paramKind() == ParameterKind.DEFAULTABLE) {
            return DEFAULT_VALUE;
        }
        return null;
    }
}