// import ballerina/io;

public type DataLoader isolated object {
    public isolated function load(anydata key);
    public isolated function get(anydata key) returns anydata|error; // need to change this function to dependently typed
    public isolated function dispatch() returns error?;
};

type Result record {|
    readonly anydata key;
    anydata|error value; // need to change this to any|error
|};

type Key record {|
    readonly anydata key;
|};

public isolated class DefaultDataLoader {
    *DataLoader;
    private final table<Key> key(key) keys = table [];
    private table<Result> key(key) resultTable = table [];
    private final (isolated function (readonly & anydata[] keys) returns anydata[]|error) loaderFunction;

    public isolated function init(isolated function (readonly & anydata[] keys) returns anydata[]|error loadFunction) {
        self.loaderFunction = loadFunction;
    }

    public isolated function load(anydata key) {
        readonly & anydata clonedKey = key.cloneReadOnly();
        lock {
            if self.keys.hasKey(clonedKey) {
                return;
            }
            self.keys.add({key: clonedKey});
        }
    }

    public isolated function get(anydata key) returns anydata|error {
        readonly & anydata clonedKey = key.cloneReadOnly();
        lock {
            if self.resultTable.hasKey(clonedKey) {
                return self.resultTable.get(clonedKey).value.clone();
            }
        }
        return error(string `No result found for the given key ${key.toString()}`);
    }

    public isolated function dispatch() returns error? {
        lock {
            readonly & anydata[] batchKeys = self.keys.toArray().'map((key) => key.key).cloneReadOnly();
            self.keys.removeAll();
            // io:println("collected keys for the batch:", batchKeys);
            anydata[] batchResult = check self.loaderFunction(batchKeys);
            foreach int i in 0 ..< batchKeys.length() {
                self.resultTable.add({key: batchKeys[i], value: batchResult[i]});
            }
        }
    }
}
