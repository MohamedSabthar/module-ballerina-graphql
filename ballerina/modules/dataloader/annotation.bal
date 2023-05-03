public type LoaderConfig record {|
    (isolated function (readonly & anydata[] keys) returns anydata[]|error) batchFuntion;
|};

public annotation  LoaderConfig  Loader on object function;