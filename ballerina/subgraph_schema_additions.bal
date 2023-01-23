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

final __Type String = {
    name: STRING,
    description: "The `String` scalar type represents textual data, represented as UTF-8 character sequences. The String " +
    "type is most often used by GraphQL to represent free-form human-readable text.",
    kind: SCALAR
};

final __Type Boolean = {
    name: BOOLEAN,
    description: "The `Boolean` scalar type represents `true` or `false`.",
    kind: SCALAR
};

__Type _Entity = {
    name: ENTITY,
    kind: UNION,
    possibleTypes: [] // populate federated entities dynamically as possibleTypes
};

final __Type _Any = {
    name: ANY,
    kind: SCALAR
};

final __Type FieldSet = {
    name: FIELD_SET,
    kind: SCALAR
};

final __Type link__Import = {
    name: LINK_IMPORT,
    kind: SCALAR
};

final __Type link__Purpose = {
    name: LINK_PURPOSE,
    kind: ENUM,
    enumValues: [
        {
            name: "SECURITY",
            description: "`SECURITY` features provide metadata necessary to securely resolve fields."
        },
        {
            name: "EXECUTION",
            description: "`EXECUTION` features provide metadata necessary for operation execution."
        }
    ]
};

final __Type _Service = {
    name: SERVICE,
    kind: OBJECT,
    fields: [sdl]
};

final __Field sdl = {
    name: SDL_FEILD,
    'type: {
        kind: NON_NULL,
        ofType: String
    },
    args: []
};

final __Field _entities = {
    name: ENTITIES_FEILD,
    'type: {
        kind: NON_NULL,
        ofType: {
            kind: LIST,
            ofType: _Entity
        }
    },
    args: [representations]
};

final __InputValue representations = {
    name: REPRESENTATIONS,
    'type: {
        kind: NON_NULL,
        ofType: {
            kind: LIST,
            ofType: {
                kind: NON_NULL,
                ofType: _Any
            }
        }
    }
};

final __Field _service = {
    name: SERVICE_FIELD,
    'type: {
        kind: NON_NULL,
        ofType: _Service
    },
    args: []
};

final __Directive 'external = {
    name: EXTERNAL_DIRECTIVE,
    locations: [FIELD_DEFINITION, OBJECT]
};

final __Directive 'requires = {
    name: REQUIRES_DIRECTIVE,
    locations: [FIELD_DEFINITION],
    args: [fields]
};

final __Directive 'provides = {
    name: PROVIDES_DIRECTIVE,
    locations: [FIELD_DEFINITION],
    args: [fields]
};

// repeatable
final __Directive 'key = {
    name: KEY_DIRECTIVE,
    locations: [OBJECT, INTERFACE],
    args: [fields, resolvable]
};

final __Directive link = {
    name: LINK_DIRECTIVE,
    locations: [SCHEMA],
    args: [url, 'as, 'for, 'import]
};

final __InputValue url = {
    name: URL,
    'type: {
        kind: NON_NULL,
        ofType: String
    }
};

final __InputValue 'as = {
    name: AS,
    'type: String
};

final __InputValue 'for = {
    name: "for",
    'type: link__Import
};

final __InputValue 'import = {
    name: "import",
    'type: {
        kind: LIST,
        ofType: link__Import
    }
};

// repeatable
final __Directive shareable = {
    name: SHAREABLE_DIRECTIVE,
    locations: [OBJECT, FIELD_DEFINITION]
};

final __Directive inaccessible = {
    name: INACCESSIBLE_DIRECTIVE,
    locations: [FIELD_DEFINITION, OBJECT, INTERFACE, UNION, ARGUMENT_DEFINITION, SCALAR, ENUM, ENUM_VALUE, INPUT_OBJECT, INPUT_FIELD_DEFINITION]
};

final __InputValue 'from = {
    name: "from",
    'type: {
        kind: NON_NULL,
        ofType: String
    }
};

// repeatable
final __Directive tag = {
    name: TAG_DIRECTIVE,
    locations: [FIELD_DEFINITION, INTERFACE, OBJECT, UNION, ARGUMENT_DEFINITION, SCALAR, ENUM, ENUM_VALUE, INPUT_OBJECT, INPUT_FIELD_DEFINITION],
    args: [
        name
    ]
};

final __Directive override = {
    name: OVERRIDE_DIRECTIVE,
    locations: [FIELD_DEFINITION],
    args: [
        'from
    ]
};

// repeatable
final __Directive composeDirective = {
    name: COMPOSE_DIRECTIVE,
    locations: [SCHEMA],
    args: [
        name
    ]
};

final __Directive extends = {
    name: EXTENDS_DIRECTIVE,
    locations: [OBJECT, INTERFACE]
};

final __InputValue fields = {
    name: FIELDS,
    'type: {
        kind: NON_NULL,
        ofType: FieldSet
    }
};

final __InputValue resolvable = {
    name: RESOLVABLE,
    'type: Boolean,
    defaultValue: "true"
};

final __InputValue name = {
    name: NAME,
    'type: {
        kind: NON_NULL,
        ofType: String
    }
};
