import ballerina/graphql;

listener graphql:Listener secureListener = new (9096, secureSocket = {
    key: {
        path: KEYSTORE_PATH,
        password: "ballerina"
    }
});

// **************** Security-Related Services ****************
// Unsecured service
service /noAuth on secureListener {
    isolated resource function get greeting() returns string {
        return "Hello World!";
    }
}

// Basic auth secured service
@graphql:ServiceConfig {
    auth: [
        {
            fileUserStoreConfig: {},
            scopes: ["write", "update"]
        }
    ],
    graphiql: {
        enabled: true
    }
}
service /basicAuth on secureListener {
    isolated resource function get greeting() returns string {
        return "Hello World!";
    }
}

// JWT auth secured service
@graphql:ServiceConfig {
    auth: [
        {
            jwtValidatorConfig: {
                issuer: "wso2",
                audience: "ballerina",
                signatureConfig: {
                    trustStoreConfig: {
                        trustStore: {
                            path: TRUSTSTORE_PATH,
                            password: "ballerina"
                        },
                        certAlias: "ballerina"
                    }
                },
                scopeKey: "scp"
            },
            scopes: ["write", "update"]
        }
    ]
}
service /jwtAuth on secureListener {
    isolated resource function get greeting() returns string {
        return "Hello World!";
    }
}

// OAuth2 auth secured service
@graphql:ServiceConfig {
    auth: [
        {
            oauth2IntrospectionConfig: {
                url: "https://localhost:9445/oauth2/introspect",
                tokenTypeHint: "access_token",
                scopeKey: "scp",
                clientConfig: {
                    secureSocket: {
                        cert: {
                            path: TRUSTSTORE_PATH,
                            password: "ballerina"
                        }
                    }
                }
            },
            scopes: ["write", "update"]
        }
    ]
}
service /oauth2 on secureListener {
    isolated resource function get greeting() returns string {
        return "Hello World!";
    }
}

// Testing multiple auth configurations support.
// OAuth2, Basic auth & JWT auth secured service
@graphql:ServiceConfig {
    auth: [
        {
            oauth2IntrospectionConfig: {
                url: "https://localhost:9445/oauth2/introspect",
                tokenTypeHint: "access_token",
                scopeKey: "scp",
                clientConfig: {
                    secureSocket: {
                        cert: {
                            path: TRUSTSTORE_PATH,
                            password: "ballerina"
                        }
                    }
                }
            },
            scopes: ["write", "update"]
        },
        {
            fileUserStoreConfig: {},
            scopes: ["write", "update"]
        },
        {
            jwtValidatorConfig: {
                issuer: "wso2",
                audience: "ballerina",
                signatureConfig: {
                    trustStoreConfig: {
                        trustStore: {
                            path: TRUSTSTORE_PATH,
                            password: "ballerina"
                        },
                        certAlias: "ballerina"
                    }
                },
                scopeKey: "scp"
            },
            scopes: ["write", "update"]
        }
    ]
}
service /multipleAuth on secureListener {
    isolated resource function get greeting() returns string {
        return "Hello World!";
    }
}

// JWT auth secured service (without scopes)
@graphql:ServiceConfig {
    auth: [
        {
            jwtValidatorConfig: {
                issuer: "wso2",
                audience: "ballerina",
                signatureConfig: {
                    trustStoreConfig: {
                        trustStore: {
                            path: TRUSTSTORE_PATH,
                            password: "ballerina"
                        },
                        certAlias: "ballerina"
                    }
                }
            }
        }
    ]
}
service /noScopes on secureListener {
    isolated resource function get greeting() returns string {
        return "Hello World!";
    }
}

// **************** Security-Related Services ****************
