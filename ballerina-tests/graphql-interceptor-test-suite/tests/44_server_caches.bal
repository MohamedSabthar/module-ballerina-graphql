import ballerina/graphql_test_common as common;
import ballerina/test;

@test:Config {
    groups: ["server_cache", "interceptors"],
    dataProvider: dataProviderServerCacheWithInterceptors
}
isolated function testServerSideCacheWithInterceptors(string documentFile, string[] resourceFileNames, json variables = (), string[] operationNames = []) returns error? {
    string url = "http://localhost:9091/field_caching_with_interceptors";
    string document = check common:getGraphqlDocumentFromFile(documentFile);
    foreach int i in 0..< resourceFileNames.length() {
        json actualPayload = check common:getJsonPayloadFromService(url, document, variables, operationNames[i]);
        json expectedPayload = check common:getJsonContentFromFile(resourceFileNames[i]);
        common:assertJsonValuesWithOrder(actualPayload, expectedPayload);
    }
}

@test:Config {
    groups: ["server_cache", "interceptor"],
    dataProvider: dataProviderServerCacheWithInterceptors
}
isolated function testServerSideCacheWithInterceptorInOperationalLevel(string documentFile, string[] resourceFileNames, json variables = (), string[] operationNames = []) returns error? {
    string url = "http://localhost:9091/caching_with_interceptor_operations";
    string document = check common:getGraphqlDocumentFromFile(documentFile);
    foreach int i in 0..< resourceFileNames.length() {
        json actualPayload = check common:getJsonPayloadFromService(url, document, variables, operationNames[i]);
        json expectedPayload = check common:getJsonContentFromFile(resourceFileNames[i]);
        common:assertJsonValuesWithOrder(actualPayload, expectedPayload);
    }
}

function dataProviderServerCacheWithInterceptors() returns map<[string, string[], json, string[]]> {
    map<[string, string[], json, string[]]> dataSet = {
        "1": ["server_cache_with_interceptors", ["server_cache_with_interceptors_1", "server_cache_with_interceptors_2", "server_cache_with_interceptors_1"], (), ["A", "B", "A"]],
        "2": ["server_cache_eviction_with_interceptors", ["server_cache_with_interceptors_1", "server_cache_with_interceptors_2", "server_cache_with_interceptors_3"], (), ["A", "B", "A"]]
    };
    return dataSet;
}