// Copyright (c) 2020, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

# Provides a set of configurations for the GraphQL service.
#
# + maxQueryDepth - The maximum depth allowed for a query
# + auth - Listener authenticaton configurations
# + contextInit - Function to initialize the context. If not provided, an empty context will be created
# + cors - The cross origin resource sharing configurations for the service
# + graphiql - GraphiQL client configurations
# + schemaString - The generated schema. This is auto-generated at the compile-time
# + interceptors - GraphQL service level interceptors
# + introspection - Whether to enable or disable the introspection on the service
public type GraphqlServiceConfig record {|
    int maxQueryDepth?;
    ListenerAuthConfig[] auth?;
    ContextInit contextInit = initDefaultContext;
    CorsConfig cors?;
    Graphiql graphiql = {};
    readonly string schemaString = "";
    readonly readonly & Interceptor[] interceptors = [];
    boolean introspection = true;
|};

# The annotation to configure a GraphQL service.
public annotation GraphqlServiceConfig ServiceConfig on service;

# Designates the GraphQL service as a federated GraphQL subgraph.
public annotation Subgraph on service;

# Describes the shape of the `graphql:Entity` annotation
# + key - GraphQL fields and subfields that contribute to the entity's primary key
# + resolveReference - Function pointer to resolve the entity. if set to nil, indicates the graph router that this
#                      subgraph does not define a reference resolver for this entity.
public type FederatedEntity record {|
    string key;
    ReferenceResolver? resolveReference;
|};

# The annotation to designates a GraphQL object type as an entity.
public annotation FederatedEntity Entity on class, type;
