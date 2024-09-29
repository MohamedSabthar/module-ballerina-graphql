import ballerina/test;
import ballerina/http; 
import ballerina/graphql_test_common as common;

@test:Config {
    groups: ["listener", "graphiql"]
}
function testGraphiqlClientWithSSL() returns error? {
    http:Client clientEP = check new ("https://localhost:9096",
        auth = {
            username: "alice",
            password: "xxx"
        },
        secureSocket = {
            cert: {
                path: TRUSTSTORE_PATH,
                password: "ballerina"
            }
        },
        httpVersion = "1.1"
    );
    http:Response|error response = clientEP->get("/graphiql");
    test:assertFalse(response is error);
    http:Response graphiqlResponse = check response;
    test:assertEquals(graphiqlResponse.getContentType(), common:CONTENT_TYPE_TEXT_HTML);
}
