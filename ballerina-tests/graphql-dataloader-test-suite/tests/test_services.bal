import ballerina/graphql;
import ballerina/graphql.dataloader;
import ballerina/http;

listener http:Listener httpListener = new (9090, httpVersion = http:HTTP_1_1);
listener graphql:Listener wrappedListener = new (httpListener);
listener graphql:Listener basicListener = new (9091);

const GRAPHQL_TRANSPORT_WS = "graphql-transport-ws";

const AUTHOR_LOADER = "authorLoader";
const AUTHOR_UPDATE_LOADER = "authorUpdateLoader";
const BOOK_LOADER = "bookLoader";

isolated function initContext(http:RequestContext requestContext, http:Request request) returns graphql:Context|error {
    graphql:Context ctx = new;
    ctx.registerDataLoader(AUTHOR_LOADER, new dataloader:DefaultDataLoader(authorLoaderFunction));
    ctx.registerDataLoader(AUTHOR_UPDATE_LOADER, new dataloader:DefaultDataLoader(authorUpdateLoaderFunction));
    ctx.registerDataLoader(BOOK_LOADER, new dataloader:DefaultDataLoader(bookLoaderFunction));
    return ctx;
}

@graphql:ServiceConfig {
    contextInit: initContext
}
service /dataloader on wrappedListener {
    function preAuthors(graphql:Context ctx, int[] ids) {
        addAuthorIdsToAuthorLoader(ctx, ids);
    }

    resource function get authors(graphql:Context ctx, int[] ids) returns AuthorData[]|error {
        dataloader:DataLoader authorLoader = ctx.getDataLoader(AUTHOR_LOADER);
        AuthorRow[] authorRows = check trap ids.map(id => check authorLoader.get(id, AuthorRow));
        return from AuthorRow authorRow in authorRows
            select new (authorRow);
    }

    function preUpdateAuthorName(graphql:Context ctx, int id, string name) {
        [int, string] key = [id, name];
        dataloader:DataLoader authorUpdateLoader = ctx.getDataLoader(AUTHOR_UPDATE_LOADER);
        authorUpdateLoader.add(key);
    }

    remote function updateAuthorName(graphql:Context ctx, int id, string name) returns AuthorData|error {
        [int, string] key = [id, name];
        dataloader:DataLoader authorUpdateLoader = ctx.getDataLoader(AUTHOR_UPDATE_LOADER);
        AuthorRow authorRow = check authorUpdateLoader.get(key);
        return new (authorRow);
    }

    resource function subscribe authors() returns stream<AuthorData> {
        lock {
            readonly & AuthorRow[] authorRows = authorTable.toArray().cloneReadOnly();
            return authorRows.'map(authorRow => new AuthorData(authorRow)).toStream();
        }
    }
}

@graphql:ServiceConfig {
    interceptors: new AuthorInterceptor(),
    contextInit: initContext
}
service /dataloader_with_interceptor on wrappedListener {
    function preAuthors(graphql:Context ctx, int[] ids) {
        addAuthorIdsToAuthorLoader(ctx, ids);
    }

    resource function get authors(graphql:Context ctx, int[] ids) returns AuthorDetail[]|error {
        dataloader:DataLoader authorLoader = ctx.getDataLoader(AUTHOR_LOADER);
        AuthorRow[] authorRows = check trap ids.map(id => check authorLoader.get(id, AuthorRow));
        return from AuthorRow authorRow in authorRows
            select new (authorRow);
    }
}

@graphql:ServiceConfig {
    interceptors: new AuthorInterceptor(),
    contextInit: isolated function(http:RequestContext requestContext, http:Request request) returns graphql:Context {
        graphql:Context ctx = new;
        ctx.registerDataLoader(AUTHOR_LOADER, new dataloader:DefaultDataLoader(faultyAuthorLoaderFunction));
        ctx.registerDataLoader(AUTHOR_UPDATE_LOADER, new dataloader:DefaultDataLoader(authorUpdateLoaderFunction));
        ctx.registerDataLoader(BOOK_LOADER, new dataloader:DefaultDataLoader(bookLoaderFunction));
        return ctx;
    }
}
service /dataloader_with_faulty_batch_function on wrappedListener {
    function preAuthors(graphql:Context ctx, int[] ids) {
        addAuthorIdsToAuthorLoader(ctx, ids);
    }

    resource function get authors(graphql:Context ctx, int[] ids) returns AuthorData[]|error {
        dataloader:DataLoader authorLoader = ctx.getDataLoader(AUTHOR_LOADER);
        AuthorRow[] authorRows = check trap ids.map(id => check authorLoader.get(id, AuthorRow));
        return from AuthorRow authorRow in authorRows
            select new (authorRow);
    }
}

function addAuthorIdsToAuthorLoader(graphql:Context ctx, int[] ids) {
    dataloader:DataLoader authorLoader = ctx.getDataLoader(AUTHOR_LOADER);
    ids.forEach(function(int id) {
        authorLoader.add(id);
    });
}

public isolated distinct service class AuthorData {
    private final readonly & AuthorRow author;

    isolated function init(AuthorRow author) {
        self.author = author.cloneReadOnly();
    }

    isolated resource function get name() returns string {
        return self.author.name;
    }

    isolated function preBooks(graphql:Context ctx) {
        dataloader:DataLoader bookLoader = ctx.getDataLoader(BOOK_LOADER);
        bookLoader.add(self.author.id);
    }

    isolated resource function get books(graphql:Context ctx) returns BookData[]|error {
        dataloader:DataLoader bookLoader = ctx.getDataLoader(BOOK_LOADER);
        BookRow[] bookrows = check bookLoader.get(self.author.id);
        return from BookRow bookRow in bookrows
            select new BookData(bookRow);
    }
}

type BookRow record {|
    readonly int id;
    string title;
    int author;
|};

type AuthorRow record {|
    readonly int id;
    string name;
|};


public isolated distinct service class AuthorDetail {
    private final readonly & AuthorRow author;

    isolated function init(AuthorRow author) {
        self.author = author.cloneReadOnly();
    }

    isolated resource function get name() returns string {
        return self.author.name;
    }

    isolated function prefetchBooks(graphql:Context ctx) {
        dataloader:DataLoader bookLoader = ctx.getDataLoader(BOOK_LOADER);
        bookLoader.add(self.author.id);
    }

    @graphql:ResourceConfig {
        interceptors: new BookInterceptor(),
        prefetchMethodName: "prefetchBooks"
    }
    isolated resource function get books(graphql:Context ctx) returns BookData[]|error {
        dataloader:DataLoader bookLoader = ctx.getDataLoader(BOOK_LOADER);
        BookRow[] bookrows = check bookLoader.get(self.author.id);
        return from BookRow bookRow in bookrows
            select new BookData(bookRow);
    }
}

public isolated distinct service class BookData {
    private final readonly & BookRow book;

    isolated function init(BookRow book) {
        self.book = book.cloneReadOnly();
    }

    isolated resource function get id() returns int {
        return self.book.id;
    }

    isolated resource function get title() returns string {
        return self.book.title;
    }
}

final isolated table<AuthorRow> key(id) authorTable = table [
    {id: 1, name: "Author 1"},
    {id: 2, name: "Author 2"},
    {id: 3, name: "Author 3"},
    {id: 4, name: "Author 4"},
    {id: 5, name: "Author 5"}
];

final isolated table<BookRow> key(id) bookTable = table [
    {id: 1, title: "Book 1", author: 1},
    {id: 2, title: "Book 2", author: 1},
    {id: 3, title: "Book 3", author: 1},
    {id: 4, title: "Book 4", author: 2},
    {id: 5, title: "Book 5", author: 2},
    {id: 6, title: "Book 6", author: 3},
    {id: 7, title: "Book 7", author: 3},
    {id: 8, title: "Book 8", author: 4},
    {id: 9, title: "Book 9", author: 5}
];


final isolated table<AuthorRow> key(id) authorTable2 = table [
    {id: 1, name: "Author 1"},
    {id: 2, name: "Author 2"},
    {id: 3, name: "Author 3"},
    {id: 4, name: "Author 4"},
    {id: 5, name: "Author 5"}
];

final isolated table<BookRow> key(id) bookTable2 = table [
    {id: 1, title: "Book 1", author: 1},
    {id: 2, title: "Book 2", author: 1},
    {id: 3, title: "Book 3", author: 1},
    {id: 4, title: "Book 4", author: 2},
    {id: 5, title: "Book 5", author: 2},
    {id: 6, title: "Book 6", author: 3},
    {id: 7, title: "Book 7", author: 3},
    {id: 8, title: "Book 8", author: 4},
    {id: 9, title: "Book 9", author: 5}
];

@graphql:ServiceConfig {
    contextInit: initContext2
}
service /caching_with_dataloader on wrappedListener {
    function preAuthors(graphql:Context ctx, int[] ids) {
        addAuthorIdsToAuthorLoader2(ctx, ids);
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            enabled: true
        }
    }
    resource function get authors(graphql:Context ctx, int[] ids) returns AuthorData2[]|error {
        dataloader:DataLoader authorLoader = ctx.getDataLoader(AUTHOR_LOADER_2);
        AuthorRow[] authorRows = check trap ids.map(id => check authorLoader.get(id, AuthorRow));
        return from AuthorRow authorRow in authorRows
            select new (authorRow);
    }

    isolated remote function updateAuthorName(graphql:Context ctx, int id, string name, boolean enableEvict = false) returns AuthorData2|error {
        if enableEvict {
            check ctx.invalidate("authors");
        }
        AuthorRow authorRow = {id: id, name};
        lock {
            authorTable2.put(authorRow.cloneReadOnly());
        }
        return new (authorRow);
    }
}

@graphql:ServiceConfig {
    cacheConfig: {
        enabled: true
    },
    contextInit: initContext2
}
service /caching_with_dataloader_operational on wrappedListener {
    function preAuthors(graphql:Context ctx, int[] ids) {
        addAuthorIdsToAuthorLoader2(ctx, ids);
    }

    resource function get authors(graphql:Context ctx, int[] ids) returns AuthorData2[]|error {
        dataloader:DataLoader authorLoader = ctx.getDataLoader(AUTHOR_LOADER_2);
        AuthorRow[] authorRows = check trap ids.map(id => check authorLoader.get(id, AuthorRow));
        return from AuthorRow authorRow in authorRows
            select new (authorRow);
    }

    isolated remote function updateAuthorName(graphql:Context ctx, int id, string name, boolean enableEvict = false) returns AuthorData2|error {
        if enableEvict {
            check ctx.invalidate("authors");
        }
        AuthorRow authorRow = {id: id, name};
        lock {
            authorTable2.put(authorRow.cloneReadOnly());
        }
        return new (authorRow);
    }
}

public isolated distinct service class AuthorData2 {
    private final readonly & AuthorRow author;

    isolated function init(AuthorRow author) {
        self.author = author.cloneReadOnly();
    }

    isolated resource function get name() returns string {
        return self.author.name;
    }

    isolated function preBooks(graphql:Context ctx) {
        dataloader:DataLoader bookLoader = ctx.getDataLoader(BOOK_LOADER_2);
        bookLoader.add(self.author.id);
    }

    isolated resource function get books(graphql:Context ctx) returns BookData[]|error {
        dataloader:DataLoader bookLoader = ctx.getDataLoader(BOOK_LOADER_2);
        BookRow[] bookrows = check bookLoader.get(self.author.id);
        return from BookRow bookRow in bookrows
            select new BookData(bookRow);
    }
}


const AUTHOR_LOADER_2 = "authorLoader2";
const BOOK_LOADER_2 = "bookLoader2";

isolated function initContext2(http:RequestContext requestContext, http:Request request) returns graphql:Context|error {
    graphql:Context ctx = new;
    ctx.registerDataLoader(AUTHOR_LOADER_2, new dataloader:DefaultDataLoader(authorLoaderFunction2));
    ctx.registerDataLoader(BOOK_LOADER_2, new dataloader:DefaultDataLoader(bookLoaderFunction2));
    return ctx;
}

function addAuthorIdsToAuthorLoader2(graphql:Context ctx, int[] ids) {
    dataloader:DataLoader authorLoader = ctx.getDataLoader(AUTHOR_LOADER_2);
    ids.forEach(function(int id) {
        authorLoader.add(id);
    });
}


