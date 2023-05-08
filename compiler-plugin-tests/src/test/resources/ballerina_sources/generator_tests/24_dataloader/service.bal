import ballerina/graphql;
import ballerina/graphql.dataloader;
import ballerina/sql;
import ballerinax/java.jdbc;
import ballerinax/mysql.driver as _;

service on new graphql:Listener(9090) {
   resource function get authors(int[] ids) returns Author[]|error {
       var query = sql:queryConcat(`SELECT * FROM authors WHERE id IN (`, sql:arrayFlattenQuery(ids), `)`);
       stream<AuthorRow, sql:Error?> authorStream = dbClient->query(query);
       return from AuthorRow authorRow in authorStream
           select new (authorRow);
   }
}


isolated distinct service class Author {
   private final readonly & AuthorRow author;

   isolated function init(AuthorRow author) {
       self.author = author.cloneReadOnly();
   }

   isolated resource function get name() returns string {
       return self.author.name;
   }

   isolated resource function get books(dataloader:DataLoader bookloader) returns Book[]|error {
       BookRow[] bookrows = check (check bookloader.get(self.author.id)).cloneWithType();
       return from BookRow bookRow in bookrows select new Book(bookRow);
   }

   @dataloader:Loader {
       batchFunction: bookLoaderFunction
   }
   isolated resource function get loadBooks(dataloader:DataLoader bookLoader) {
       bookLoader.load(self.author.id);
   }
}

isolated distinct service class Book {
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

isolated function bookLoaderFunction(readonly & anydata[] ids) returns BookRow[][]|error {
    readonly & int[] keys = <readonly & int[]>ids;
    var query = sql:queryConcat(`SELECT * FROM books WHERE id IN (`, sql:arrayFlattenQuery(keys), `)`);
    stream<BookRow, sql:Error?> bookStream = dbClient->query(query);
    map<BookRow[]> authorsBooks = {};
    checkpanic from BookRow bookRow in bookStream
        do {
            string key = bookRow.author.toString();
            if !authorsBooks.hasKey(key) {
                authorsBooks[key] = [];
            }
            authorsBooks.get(key).push(bookRow);
        };
    final readonly & map<BookRow[]> clonedMap = authorsBooks.cloneReadOnly();
    return keys.'map(key => clonedMap[key.toString()] ?: []);
};

final jdbc:Client dbClient = check new ("jdbc:mysql://localhost:3306/mydatabase", "root", "password");

public type  BookRow record {
    int id;
    string title;
    int author;
    int publisher;
};

public type  AuthorRow record {
    int id;
    string name;
};