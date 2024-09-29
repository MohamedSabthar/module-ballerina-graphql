import ballerina/graphql;
import ballerina/lang.runtime;
import ballerina/http;
import ballerina/constraint;

listener graphql:Listener subscriptionListener = new (9099);
listener http:Listener http2Listener = new http:Listener(9190);
listener graphql:Listener http2BasedListener = new (http2Listener);
listener http:Listener http1Listener = new http:Listener(9191, httpVersion = http:HTTP_1_0);
listener graphql:Listener http1BasedListener = new (http1Listener);
listener graphql:Listener serviceTypeListener = new (9092);
listener graphql:Listener basicListener = new (9091);

public string[] namesArray = ["Walter", "Skyler"];

service /subscriptions on subscriptionListener {
    isolated resource function get name() returns string {
        return "Walter White";
    }

    resource function subscribe name() returns stream<string, error?> {
        return namesArray.toStream();
    }

    isolated resource function subscribe messages() returns stream<int, error?> {
        int[] intArray = [1, 2, 3, 4, 5];
        return intArray.toStream();
    }

    isolated resource function subscribe stringMessages() returns stream<string?, error?> {
        string?[] stringArray = [(), "1", "2", "3", "4", "5"];
        return stringArray.toStream();
    }

    isolated resource function subscribe books() returns stream<Book, error?> {
        Book[] books = [
            {name: "Crime and Punishment", author: "Fyodor Dostoevsky"},
            {name: "A Game of Thrones", author: "George R.R. Martin"}
        ];
        return books.toStream();
    }

    isolated resource function subscribe students() returns stream<StudentService, error?> {
        StudentService[] students = [new StudentService(1, "Eren Yeager"), new StudentService(2, "Mikasa Ackerman")];
        return students.toStream();
    }

    isolated resource function subscribe filterValues(int value) returns stream<int, error?> {
        int[] intArray = [1, 2, 3, 4, 5];
        int[] filteredArray = [];
        foreach int i in intArray {
            if i < value {
                filteredArray.push(i);
            }
        }
        return filteredArray.toStream();
    }

    isolated resource function subscribe values() returns stream<int>|error {
        int[] array = [];
        int _ = check trap array.remove(0);
        return array.toStream();
    }

    isolated resource function subscribe multipleValues() returns stream<(PeopleService)>|error {
        StudentService s = new StudentService(1, "Jesse Pinkman");
        TeacherService t = new TeacherService(0, "Walter White", "Chemistry");
        return [s, t].toStream();
    }

    isolated resource function subscribe evenNumber() returns stream<int, error?> {
        EvenNumberGenerator evenNumberGenerator = new;
        return new (evenNumberGenerator);
    }

    isolated resource function subscribe refresh() returns stream<string> {
        RefreshData dataRefersher = new;
        return new (dataRefersher);
    }
}


public type Book readonly & record {
    string name;
    string author;
};

public distinct isolated service class StudentService {
    private final int id;
    private final string name;

    public isolated function init(int id, string name) {
        self.id = id;
        self.name = name;
    }

    isolated resource function get id() returns int {
        return self.id;
    }

    isolated resource function get name() returns string {
        return self.name;
    }
}

public distinct isolated service class TeacherService {
    private final int id;
    private string name;
    private string subject;

    public isolated function init(int id, string name, string subject) {
        self.id = id;
        self.name = name;
        self.subject = subject;
    }

    isolated resource function get id() returns int {
        return self.id;
    }

    isolated resource function get name() returns string {
        lock {
            return self.name;
        }
    }

    isolated function setName(string name) {
        lock {
            self.name = name;
        }
    }

    isolated resource function get subject() returns string {
        lock {
            return self.subject;
        }
    }

    isolated function setSubject(string subject) {
        lock {
            self.subject = subject;
        }
    }

    isolated resource function get holidays() returns Weekday[] {
        return [SATURDAY, SUNDAY];
    }

    isolated resource function get school() returns School {
        return new School("CHEM");
    }
}


public type PeopleService StudentService|TeacherService;


class EvenNumberGenerator {
    private int i = 0;

    public isolated function next() returns record {|int value;|}|error? {
        self.i += 2;
        if self.i == 4 {
            return error("Runtime exception");
        }
        if self.i > 6 {
            return;
        }
        return {value: self.i};
    }
}

class RefreshData {
    public isolated function next() returns record {|string value;|}? {
        // emit data every one second
        runtime:sleep(1);
        return {value: "data"};
    }
}

public enum Weekday {
    SUNDAY,
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY
}

public distinct isolated service class School {
    private string name;

    public isolated function init(string name) {
        self.name = name;
    }

    isolated resource function get name() returns string {
        lock {
            return self.name;
        }
    }

    # Get the opening days of the school.
    # + return - The set of the weekdays the school is open
    # # Deprecated
    # School is now online.
    @deprecated
    isolated resource function get openingDays() returns Weekday[] {
        return [MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY];
    }
}

listener http:Listener httpListener = new (9090, httpVersion = http:HTTP_1_1);
listener graphql:Listener wrappedListener = new (httpListener);

service /reviews on wrappedListener {
    resource function get greet() returns string {
        return "Welcome!";
    }

    resource function subscribe live() returns stream<Review> {
        return reviews.toArray().toStream();
    }

    resource function subscribe accountUpdates() returns stream<AccountRecords> {
        map<AccountDetails> details = {acc1: new AccountDetails("James", 2022), acc2: new AccountDetails("Paul", 2015)};
        map<AccountDetails> updatedDetails = {...details};
        updatedDetails["acc1"] = new AccountDetails("James Deen", 2022);
        return [{details}, {details: updatedDetails}].toStream();
    }
}


public type Review record {|
  Product product;
  int score;
  string description;
|};

table<Review> reviews = table [
    {product: new ("1"), score: 20, description: "Product 01"},
    {product: new ("2"), score: 20, description: "Product 02"},
    {product: new ("3"), score: 20, description: "Product 03"},
    {product: new ("4"), score: 20, description: "Product 04"},
    {product: new ("5"), score: 20, description: "Product 05"}
];

public type AccountRecords record {|
    map<AccountDetails> details;
|};


public service class AccountDetails {
    final string name;
    final int createdYear;

    function init(string name, int createdYear) {
        self.name = name;
        self.createdYear = createdYear;
    }

    resource function get name() returns string {
        return self.name;
    }

    resource function get createdYear() returns int {
        return self.createdYear;
    }
}


public service class Product {
    private final string id;

    function init(string id) {
        self.id = id;
    }

    resource function get id() returns string {
        return self.id;
    }
}

graphql:Service subscriptionService = service object {

    isolated resource function get name() returns string {
        return "Walter White";
    }

    isolated resource function subscribe messages() returns stream<int, error?> {
        int[] intArray = [1, 2, 3, 4, 5];
        return intArray.toStream();
    }
};

isolated service /service_with_http1 on http1BasedListener {
    isolated resource function get greet() returns string {
        return "welcome!";
    }

    isolated resource function subscribe messages() returns stream<int, error?> {
        int[] intArray = [1, 2, 3, 4, 5];
        return intArray.toStream();
    }
}

@graphql:ServiceConfig {
    contextInit:
    isolated function(http:RequestContext requestContext, http:Request request) returns graphql:Context|error {
        graphql:Context context = new;
        context.set("scope", check request.getHeader("scope"));
        return context;
    }
}
service /context on serviceTypeListener {
    isolated resource function get greet() returns string {
        return "welcome!";
    }

    isolated resource function subscribe messages(graphql:Context context) returns stream<int, error?>|error {
        var scope = context.get("scope");
        if scope is string && scope == "admin" {
            int[] intArray = [1, 2, 3, 4, 5];
            return intArray.toStream();
        }
        return error("You don't have permission to retrieve data");
    }
}

service /constraints on basicListener {
    isolated resource function get greet() returns string {
        return "welcome!";
    }

    isolated resource function subscribe movie(MovieDetails movie) returns stream<Reviews?, error?> {
        return movie.reviews.toStream();
    }
}

public type MovieDetails record {|
    @constraint:String {
        minLength: 1,
        maxLength: 10
    }
    string name;

    @constraint:Int {
        minValue: 18
    }
    int downloads;

    @constraint:Float {
        minValue: 1.5
    }
    float imdb;

    @constraint:Array {
        length: 1
    }
    Reviews?[] reviews;
|};

public type Reviews readonly & record {|
    @constraint:Array {
        maxLength: 2
    }
    string[] comments;

    @constraint:Int {
        minValueExclusive: 0,
        maxValueExclusive: 6
    }
    int stars;
|};