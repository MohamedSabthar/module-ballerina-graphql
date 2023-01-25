import ballerina/io;
import ballerina/graphql;

@graphql:ServiceConfig{
    graphiql: {
        enabled: true
    },
    cors: {allowOrigins: ["*"]},
    isSubgraph: true
}
service on new graphql:Listener(4040) {
    resource function get me() returns Userf {
        return new;
    }

    resource function get temp(int[] data) returns int[] {
        return data;
    }

    resource function get _entities(json[] representations) returns graphql:Entity?[]|error{
        io:println(representations);
        graphql:Entity?[] entities = [];
        foreach json rep in representations {
            match rep.__typename {
                "Userf" => {
                    entities.push(new Userf());
                }
                _ => {
                    entities.push(());
                }
            }
        }
        return entities;
    }
}

@graphql:Key{
    fields: "email"
}
distinct service class Userf {
    *graphql:Entity;
    resource function get email() returns string {
        return "sabthar@wso2.com";
    }

    resource function get name() returns string {
        return "sabthar";
    }

    resource function get resolveReference(json representation) returns error|Userf? {
        return new;
    }
}