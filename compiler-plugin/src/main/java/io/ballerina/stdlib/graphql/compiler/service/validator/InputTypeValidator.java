package io.ballerina.stdlib.graphql.compiler.service.validator;

import io.ballerina.compiler.api.symbols.ArrayTypeSymbol;
import io.ballerina.compiler.api.symbols.IntersectionTypeSymbol;
import io.ballerina.compiler.api.symbols.RecordFieldSymbol;
import io.ballerina.compiler.api.symbols.RecordTypeSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.stdlib.graphql.compiler.diagnostics.CompilationDiagnostic;
import io.ballerina.tools.diagnostics.Location;

import java.util.List;

import static io.ballerina.stdlib.graphql.compiler.Utils.getEffectiveType;
import static io.ballerina.stdlib.graphql.compiler.Utils.isFileUploadParameter;
import static io.ballerina.stdlib.graphql.compiler.Utils.isPrimitiveTypeSymbol;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.getLocation;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.isReservedFederatedTypeName;
import static io.ballerina.stdlib.graphql.compiler.service.validator.ValidatorUtils.updateContext;

/**
 * Validate ballerina types used as GraphQL input parameters.
 */
public class InputTypeValidator {

    private static final CharSequence FIELD_PATH_SEPARATOR = ".";
    private final SyntaxNodeAnalysisContext context;
    private final List<TypeSymbol> existingInputObjectTypes;
    private final List<TypeSymbol> existingReturnTypes;
    private final List<String> currentFieldPath;
    private TypeSymbol rootInputParameterTypeSymbol;
    private int arrayDimension = 0;
    private boolean errorOccurred = false;
    private String directiveClassName;

    public InputTypeValidator(SyntaxNodeAnalysisContext context, List<TypeSymbol> existingInputObjectTypes,
                              List<TypeSymbol> existingReturnTypes, List<String> currentFieldPath) {
        this.context = context;
        this.existingInputObjectTypes = existingInputObjectTypes;
        this.currentFieldPath = currentFieldPath;
        this.existingReturnTypes = existingReturnTypes;
    }

    public void validateInputParameterType(TypeSymbol typeSymbol, Location location, boolean isResourceMethod) {
        if (isFileUploadParameter(typeSymbol)) {
            String methodName = currentFieldPath.get(currentFieldPath.size() - 1);
            if (this.arrayDimension > 1) {
                addDiagnostic(CompilationDiagnostic.MULTI_DIMENSIONAL_UPLOAD_ARRAY, location, methodName);
            }
            if (isResourceMethod) {
                addDiagnostic(CompilationDiagnostic.INVALID_FILE_UPLOAD_IN_RESOURCE_FUNCTION, location, methodName);
            }
        } else {
            validateInputType(typeSymbol, location, isResourceMethod);
        }
    }

    public void validateDirectiveInputParameterType(TypeSymbol typeSymbol, Location location,
                                                    String directiveClassName) {
        this.directiveClassName = directiveClassName;
        if (isFileUploadParameter(typeSymbol)) {
            addDiagnostic(CompilationDiagnostic.INVALID_FILE_UPLOAD_IN_DIRECTIVE, location, directiveClassName);
        } else {
            validateInputType(typeSymbol, location, false);
        }
        this.directiveClassName = null;
    }

    private void validateInputType(TypeSymbol typeSymbol, Location location, boolean isResourceMethod) {
        setRootInputParameterTypeSymbol(typeSymbol);
        switch (typeSymbol.typeKind()) {
            case INT:
            case INT_SIGNED8:
            case INT_UNSIGNED8:
            case INT_SIGNED16:
            case INT_UNSIGNED16:
            case INT_SIGNED32:
            case INT_UNSIGNED32:
            case STRING:
            case STRING_CHAR:
            case BOOLEAN:
            case DECIMAL:
            case FLOAT:
                break;
            case TYPE_REFERENCE:
                validateInputParameterType((TypeReferenceTypeSymbol) typeSymbol, location, isResourceMethod);
                break;
            case UNION:
                validateInputParameterType((UnionTypeSymbol) typeSymbol, location, isResourceMethod);
                break;
            case ARRAY:
                validateInputParameterType((ArrayTypeSymbol) typeSymbol, location, isResourceMethod);
                break;
            case INTERSECTION:
                validateInputParameterType((IntersectionTypeSymbol) typeSymbol, location, isResourceMethod);
                break;
            case RECORD:
                if (this.directiveClassName == null) {
                    addDiagnostic(CompilationDiagnostic.INVALID_ANONYMOUS_INPUT_TYPE, location, typeSymbol.signature(),
                                  getCurrentFieldPath());
                } else {
                    addDiagnostic(CompilationDiagnostic.INVALID_ANONYMOUS_INPUT_TYPE_IN_DIRECTIVE, location,
                                  typeSymbol.signature(), this.directiveClassName);
                }
                break;
            default:
                if (this.directiveClassName == null) {
                    addDiagnostic(CompilationDiagnostic.INVALID_INPUT_PARAMETER_TYPE, location,
                                  rootInputParameterTypeSymbol.signature(), getCurrentFieldPath());
                } else {
                    addDiagnostic(CompilationDiagnostic.INVALID_INPUT_PARAMETER_TYPE_IN_DIRECTIVE, location,
                                  rootInputParameterTypeSymbol.signature(), this.directiveClassName);
                }
        }
        if (isRootInputParameterTypeSymbol(typeSymbol)) {
            resetRootInputParameterTypeSymbol();
        }
    }


    private void setRootInputParameterTypeSymbol(TypeSymbol typeSymbol) {
        if (rootInputParameterTypeSymbol == null) {
            rootInputParameterTypeSymbol = typeSymbol;
        }
    }

    private void resetRootInputParameterTypeSymbol() {
        rootInputParameterTypeSymbol = null;
    }

    private boolean isRootInputParameterTypeSymbol(TypeSymbol typeSymbol) {
        return rootInputParameterTypeSymbol == typeSymbol;
    }

    private void validateInputParameterType(ArrayTypeSymbol arrayTypeSymbol, Location location,
                                            boolean isResourceMethod) {
        this.arrayDimension++;
        TypeSymbol memberTypeSymbol = arrayTypeSymbol.memberTypeDescriptor();
        validateInputParameterType(memberTypeSymbol, location, isResourceMethod);
        this.arrayDimension--;
    }

    private void validateInputParameterType(TypeReferenceTypeSymbol typeSymbol, Location location,
                                            boolean isResourceMethod) {
        TypeSymbol typeDescriptor = typeSymbol.typeDescriptor();
        Symbol typeDefinition = typeSymbol.definition();
        // noinspection OptionalGetWithoutIsPresent
        String typeName = typeDefinition.getName().get();
        if (typeDefinition.kind() == SymbolKind.ENUM) {
            if (isReservedFederatedTypeName(typeName)) {
                addDiagnostic(CompilationDiagnostic.INVALID_USE_OF_RESERVED_TYPE_AS_INPUT_TYPE, location, typeName);
            }
            return;
        }
        if (typeDefinition.kind() == SymbolKind.TYPE_DEFINITION && typeDescriptor.typeKind() == TypeDescKind.RECORD) {
            validateInputParameterType((RecordTypeSymbol) typeDescriptor, location, typeName, isResourceMethod);
            return;
        }
        if (isPrimitiveTypeSymbol(typeDescriptor)) {
            // noinspection OptionalGetWithoutIsPresent
            addDiagnostic(CompilationDiagnostic.UNSUPPORTED_PRIMITIVE_TYPE_ALIAS, getLocation(typeSymbol, location),
                          typeSymbol.getName().get(), typeDescriptor.typeKind().getName());
            return;
        }
        validateInputParameterType(typeDescriptor, location, isResourceMethod);
    }

    private void validateInputParameterType(UnionTypeSymbol unionTypeSymbol, Location location,
                                            boolean isResourceMethod) {
        boolean foundDataType = false;
        int dataTypeCount = 0;
        for (TypeSymbol memberType : unionTypeSymbol.userSpecifiedMemberTypes()) {
            if (memberType.typeKind() == TypeDescKind.ERROR) {
                if (this.directiveClassName == null) {
                    addDiagnostic(CompilationDiagnostic.INVALID_INPUT_PARAMETER_TYPE, location,
                                  TypeDescKind.ERROR.getName(), this.getCurrentFieldPath());
                } else {
                    addDiagnostic(CompilationDiagnostic.INVALID_INPUT_PARAMETER_TYPE_IN_DIRECTIVE, location,
                                  TypeDescKind.ERROR.getName(), this.directiveClassName);
                }
            } else if (memberType.typeKind() != TypeDescKind.NIL) {
                foundDataType = true;
                dataTypeCount++;
                if (memberType.typeKind() != TypeDescKind.SINGLETON) {
                    validateInputParameterType(memberType, location, isResourceMethod);
                }
            }
        }
        if (!foundDataType) {
            addDiagnostic(CompilationDiagnostic.INVALID_INPUT_TYPE, location);
        } else if (dataTypeCount > 1) {
            addDiagnostic(CompilationDiagnostic.INVALID_INPUT_TYPE_UNION, location);
        }
    }

    private void validateInputParameterType(IntersectionTypeSymbol intersectionTypeSymbol, Location location,
                                            boolean isResourceMethod) {
        TypeSymbol effectiveType = getEffectiveType(intersectionTypeSymbol);
        if (effectiveType.typeKind() == TypeDescKind.RECORD) {
            String typeName = effectiveType.getName().orElse(effectiveType.signature());
            validateInputParameterType((RecordTypeSymbol) effectiveType, location, typeName, isResourceMethod);
        } else {
            validateInputParameterType(effectiveType, location, isResourceMethod);
        }
    }


    private void validateInputParameterType(RecordTypeSymbol recordTypeSymbol, Location location, String recordTypeName,
                                            boolean isResourceMethod) {
        if (this.existingReturnTypes.contains(recordTypeSymbol)) {
            if (this.directiveClassName == null) {
                addDiagnostic(CompilationDiagnostic.INVALID_RESOURCE_INPUT_OBJECT_PARAM, location,
                              getCurrentFieldPath(), recordTypeName);
            } else {
                addDiagnostic(CompilationDiagnostic.INVALID_DIRECTIVE_INPUT_OBJECT_PARAM, location,
                              this.directiveClassName, recordTypeName);
            }

        } else {
            if (this.existingInputObjectTypes.contains(recordTypeSymbol)) {
                return;
            }
            this.existingInputObjectTypes.add(recordTypeSymbol);
            if (isReservedFederatedTypeName(recordTypeName)) {
                addDiagnostic(CompilationDiagnostic.INVALID_USE_OF_RESERVED_TYPE_AS_INPUT_TYPE, location,
                              recordTypeName);
            }
            for (RecordFieldSymbol recordFieldSymbol : recordTypeSymbol.fieldDescriptors().values()) {
                validateInputType(recordFieldSymbol.typeDescriptor(), location, isResourceMethod);
            }
        }
    }


    private void addDiagnostic(CompilationDiagnostic compilationDiagnostic, Location location, Object... args) {
        this.errorOccurred = true;
        updateContext(this.context, compilationDiagnostic, location, args);
    }


    private String getCurrentFieldPath() {
        return String.join(FIELD_PATH_SEPARATOR, this.currentFieldPath);
    }

    public boolean isErrorOccurred() {
        return errorOccurred;
    }
}
