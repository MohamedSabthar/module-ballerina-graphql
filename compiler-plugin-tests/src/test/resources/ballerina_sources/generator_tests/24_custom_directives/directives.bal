import ballerina/graphql;

@graphql:DirectiveConfig {
     'on: graphql:FIELD,
     name: "sort"
}
readonly service class Sort {
    *graphql:Directive;
    Direction direction;

    function init(Direction direction) {
        self.direction = direction;
    }

    isolated remote function applyOnField(graphql:Context ctx, graphql:Field 'field) {
       
    }
}
