type ConnectionInitMessage record {|
    WS_INIT 'type;
    map<json> payload?;
|};

type ConnectionAckMessage record {|
    WS_ACK 'type;
    map<json> payload?;
|};

type PingMessage record {|
    WS_PING 'type;
    map<json> payload?;
|};

type PongMessage record {|
    WS_PONG 'type;
    map<json> payload?;
|};

type SubscribeMessage record {|
    string id;
    WS_SUBSCRIBE 'type;
    record {|
        string operationName?;
        string query;
        map<json> variables?;
        map<json> extensions?;
    |} payload;
|};

type NextMessage record {|
    string id;
    WS_NEXT 'type;
    map<json> payload;
|};

type ErrorMessage record {|
    string id;
    WS_ERROR 'type;
    ErrorDetail[] payload;
|};

type CompleteMessage record {|
    string id;
    WS_COMPLETE 'type;
|};
