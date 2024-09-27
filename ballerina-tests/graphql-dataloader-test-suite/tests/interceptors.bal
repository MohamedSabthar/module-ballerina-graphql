import ballerina/graphql;

readonly service class AuthorInterceptor {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata {
        var data = context.resolve('field);
        // Return only the first author
        return ('field.getName() == "authors" && data is anydata[]) ? [data[0]] : data;
    }
}

readonly service class BookInterceptor {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field) returns anydata {
        var books = context.resolve('field);
        // Return only the first book
        return (books is anydata[]) ? [books[0]] : books;
    }
}