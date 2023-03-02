import ballerina/test;

@test:Config {
    groups: ["parallel"]
}
function testResolversExecutesParallely() returns error? {
    string url = "http://localhost:9090/parallel";
    string document = "query { a b }";
    json actualPayload = check getJsonPayloadFromService(url, document);
    json expectedPayload = {data: { a: "Hello World!", b: "Hello World"} };
    assertJsonValuesWithOrder(actualPayload, expectedPayload);
}