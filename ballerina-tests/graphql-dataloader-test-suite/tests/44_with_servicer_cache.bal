import ballerina/graphql_test_common as common;
import ballerina/test;

@test:Config {
    groups: ["server_cache", "data_loader"],
    dataProvider: dataProviderServerCacheWithDataloader
}
isolated function testServerSideCacheWithDataLoader(string documentFile, string[] resourceFileNames, json variables = (), string[] operationNames = []) returns error? {
    string url = "http://localhost:9090/caching_with_dataloader";
    string document = check common:getGraphqlDocumentFromFile(documentFile);
    foreach int i in 0..< resourceFileNames.length() {
        json actualPayload = check common:getJsonPayloadFromService(url, document, variables, operationNames[i]);
        json expectedPayload = check common:getJsonContentFromFile(resourceFileNames[i]);
        common:assertJsonValuesWithOrder(actualPayload, expectedPayload);
    }
    resetDispatchCounters();
}

function dataProviderServerCacheWithDataloader() returns map<[string, string[], json, string[]]> {
    map<[string, string[], json, string[]]> dataSet = {
        "1": ["server_cache_with_dataloader", ["server_cache_with_dataloader_1", "server_cache_with_dataloader_2", "server_cache_with_dataloader_1"], (), ["A", "B", "A"]],
        "2": ["server_cache_eviction_with_dataloader", ["server_cache_with_dataloader_1", "server_cache_with_dataloader_2", "server_cache_with_dataloader_3"], (), ["A", "B", "A"]]
    };
    return dataSet;
}

@test:Config {
    groups: ["server_cache", "data_loader"],
    dataProvider: dataProviderServerCacheWithDataloaderInOperationalLevel
}
isolated function testServerSideCacheWithDataLoaderInOperationalLevel(string documentFile, string[] resourceFileNames, json variables = (), string[] operationNames = []) returns error? {
    string url = "http://localhost:9090/caching_with_dataloader_operational";
    string document = check common:getGraphqlDocumentFromFile(documentFile);
    foreach int i in 0..< resourceFileNames.length() {
        json actualPayload = check common:getJsonPayloadFromService(url, document, variables, operationNames[i]);
        json expectedPayload = check common:getJsonContentFromFile(resourceFileNames[i]);
        common:assertJsonValuesWithOrder(actualPayload, expectedPayload);
    }
    resetDispatchCounters();
}

function dataProviderServerCacheWithDataloaderInOperationalLevel() returns map<[string, string[], json, string[]]> {
    map<[string, string[], json, string[]]> dataSet = {
        "1": ["server_cache_with_dataloader_operational", ["server_cache_with_dataloader_3", "server_cache_with_dataloader_5", "server_cache_with_dataloader_3"], (), ["A", "B", "A"]],
        "2": ["server_cache_eviction_with_dataloader_operational", ["server_cache_with_dataloader_3", "server_cache_with_dataloader_5", "server_cache_with_dataloader_4"], (), ["A", "B", "A"]]
    };
    return dataSet;
}