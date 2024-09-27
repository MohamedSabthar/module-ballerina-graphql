import ballerina/graphql;
import ballerina/http;

listener graphql:Listener basicListener = new (9091);
listener graphql:Listener serviceTypeListener = new (9092);
listener graphql:Listener subscriptionListener = new (9099);

@graphql:ServiceConfig {
    interceptors: [new StringInterceptor4(), new StringInterceptor5(), new StringInterceptor6()]
}
service /intercept_string on basicListener {
    @graphql:ResourceConfig {
        interceptors: [new StringInterceptor1(), new StringInterceptor2(), new StringInterceptor3()]
    }
    resource function get enemy() returns string {
        return "voldemort";
    }
}

@graphql:ServiceConfig {
    interceptors: [new Counter(), new Counter(), new Counter()]
}
service /intercept_int on basicListener {
    @graphql:ResourceConfig {
        interceptors: [new Counter(), new Counter(), new Counter()]
    }
    isolated resource function get age() returns int {
        return 23;
    }
}

@graphql:ServiceConfig {
    interceptors: [new RecordInterceptor1(), new LogSubfields()]
}
service /intercept_records on basicListener {
    isolated resource function get profile() returns Person {
        return {
            name: "Albus Percival Wulfric Brian Dumbledore",
            age: 80,
            address: {number: "101", street: "Mould-on-the-Wold", city: "London"}
        };
    }

    @graphql:ResourceConfig {
        interceptors: new RecordInterceptor2()
    }
    isolated resource function get contact() returns Contact {
        return {
            number: "+12345678"
        };
    }
}

@graphql:ServiceConfig {
    interceptors: [new HierarchicalPath1(), new HierarchicalPath3()]
}
service /intercept_hierarchical on basicListener {
    @graphql:ResourceConfig {
        interceptors: new HierarchicalPath2()
    }
    isolated resource function get name/first() returns string {
        return "Sherlock";
    }

    isolated resource function get name/last() returns string {
        return "Holmes";
    }
}

@graphql:ServiceConfig {
    interceptors: new Destruct1()
}
service /intercept_service_obj_array1 on basicListener {
    resource function get students() returns StudentService[] {
        return [new StudentService(45, "Ron Weasly"), new StudentService(46, "Hermione Granger")];
    }

    @graphql:ResourceConfig {
        interceptors: [new Destruct2()]
    }
    resource function get teachers() returns TeacherService[] {
        TeacherService t1 = new TeacherService(45, "Severus Snape", "Defence Against the Dark Arts");
        return [t1];
    }
}

@graphql:ServiceConfig {
    interceptors: new ServiceObjectInterceptor1()
}
service /intercept_service_obj on basicListener {
    resource function get teacher() returns TeacherService {
        return new TeacherService(2, "Severus Snape", "Defence Against the Dark Arts");
    }

    @graphql:ResourceConfig {
        interceptors: [new ServiceObjectInterceptor3()]
    }
    resource function get student() returns StudentService {
        return new StudentService(1, "Harry Potter");
    }
}

@graphql:ServiceConfig {
    interceptors: new ServiceObjectInterceptor2()
}
service /intercept_service_obj_array2 on basicListener {
    resource function get students() returns StudentService[] {
        return [new StudentService(45, "Ron Weasly"), new StudentService(46, "Hermione Granger")];
    }

    @graphql:ResourceConfig {
        interceptors: [new ServiceObjectInterceptor4()]
    }
    resource function get teachers() returns TeacherService[] {
        return [new TeacherService(2, "Severus Snape", "Defence Against the Dark Arts")];
    }
}

@graphql:ServiceConfig {
    interceptors: new ArrayInterceptor1()
}
service /intercept_arrays on basicListener {
    @graphql:ResourceConfig {
        interceptors: new ArrayInterceptor2()
    }
    resource function get houses() returns string[] {
        return ["Gryffindor(Fire)", "Hufflepuff(Earth)"];
    }
}

@graphql:ServiceConfig {
    interceptors: new EnumInterceptor1()
}
service /intercept_enum on basicListener {
    @graphql:ResourceConfig {
        interceptors: [new EnumInterceptor2()]
    }
    isolated resource function get holidays() returns Weekday[] {
        return [];
    }
}

@graphql:ServiceConfig {
    interceptors: new UnionInterceptor1()
}
service /intercept_unions on serviceTypeListener {
    isolated resource function get profile1(int id) returns StudentService|TeacherService {
        if id < 100 {
            return new StudentService(1, "Jesse Pinkman");
        }
        return new TeacherService(737, "Walter White", "Chemistry");
    }

    @graphql:ResourceConfig {
        interceptors: new UnionInterceptor2()
    }
    isolated resource function get profile2(int id) returns StudentService|TeacherService {
        if id > 100 {
            return new StudentService(1, "Jesse Pinkman");
        }
        return new TeacherService(737, "Walter White", "Chemistry");
    }
}

@graphql:ServiceConfig {
    interceptors: [new RecordFieldInterceptor1(), new RecordFieldInterceptor2(), new ServiceLevelInterceptor(), new RecordFieldInterceptor3()]
}
service /intercept_record_fields on basicListener {
    isolated resource function get profile() returns Person {
        return {
            name: "Rubeus Hagrid",
            age: 70,
            address: {number: "103", street: "Mould-on-the-Wold", city: "London"}
        };
    }

    isolated resource function get newProfile() returns Person? {
        return {
            name: "Rubeus Hagrid",
            age: 70,
            address: {number: "103", street: "Mould-on-the-Wold", city: "London"}
        };
    }
}

@graphql:ServiceConfig {
    interceptors: new MapInterceptor1()
}
service /intercept_map on basicListener {
    private final Languages languages;

    function init() {
        self.languages = {
            name: {
                backend: "Ballerina",
                frontend: "JavaScript",
                data: "Python",
                native: "C++"
            }
        };
    }

    isolated resource function get languages() returns Languages {
        return self.languages;
    }

    @graphql:ResourceConfig {
        interceptors: new MapInterceptor2()
    }
    isolated resource function get updatedLanguages() returns Languages {
        return {
            name: {
                backend: "Ruby",
                frontend: "Java",
                data: "Ballerina",
                native: "C++"
            }
        };
    }
}

@graphql:ServiceConfig {
    interceptors: new TableInterceptor1()
}
service /intercept_table on basicListener {
    isolated resource function get employees() returns EmployeeTable? {
        return employees;
    }

    @graphql:ResourceConfig {
        interceptors: new TableInterceptor2()
    }
    isolated resource function get oldEmployees() returns EmployeeTable? {
        return employees;
    }
}

@graphql:ServiceConfig {
    interceptors: [new InterceptMutation1(), new ServiceLevelInterceptor()]
}
isolated service /mutation_interceptor on basicListener {
    private Person p;

    isolated function init() {
        self.p = p2.clone();
    }

    isolated resource function get person() returns Person {
        lock {
            return self.p;
        }
    }

    isolated remote function setName(string name) returns Person {
        lock {
            Person p = {name: name, age: self.p.age, address: self.p.address};
            self.p = p;
            return self.p;
        }
    }

    @graphql:ResourceConfig {
        interceptors: new InterceptMutation2()
    }
    isolated remote function setAge(int age) returns Person {
        lock {
            Person p = {name: self.p.name, age: age, address: self.p.address};
            self.p = p;
            return self.p;
        }
    }

    isolated resource function get customer() returns Customer {
        return new (1, "Sherlock");
    }

    isolated resource function get newPerson() returns Person? {
        lock {
            return self.p;
        }
    }
}
@graphql:ServiceConfig {
    interceptors: new ErrorInterceptor1()
}
service /intercept_errors1 on basicListener {
    isolated resource function get greet() returns string|error {
        return error("This is an invalid field!");
    }
}

@graphql:ServiceConfig {
    interceptors: [new ErrorInterceptor1()]
}
service /intercept_errors2 on basicListener {
    isolated resource function get friends() returns string[] {
        return ["Harry", "Ron", "Hermione"];
    }
}

@graphql:ServiceConfig {
    interceptors: new ErrorInterceptor1()
}
service /intercept_errors3 on basicListener {
    isolated resource function get person() returns Person {
        return {
            name: "Albus Percival Wulfric Brian Dumbledore",
            age: 80,
            address: {number: "101", street: "Mould-on-the-Wold", city: "London"}
        };
    }
}

@graphql:ServiceConfig {
    interceptors: [new Execution1(), new Execution2()],
    contextInit:
    isolated function(http:RequestContext requestContext, http:Request request) returns graphql:Context|error {
        graphql:Context context = new;
        context.set("subject", "Ballerina");
        context.set("beVerb", "is");
        context.set("object", "purpose");
        return context;
    }
}
service /intercept_order on basicListener {
    isolated resource function get quote() returns string {
        return "an open-source";
    }

    @graphql:ResourceConfig {
        interceptors: [new Execution3(), new Execution4()]
    }
    isolated resource function get status() returns string {
        return "general";
    }
}

@graphql:ServiceConfig {
    interceptors: new AccessGrant()
}
service /intercept_erros_with_hierarchical on basicListener {
    resource function get name() returns string {
        return "Walter";
    }

    resource function get age() returns int? {
        return 67;
    }

    resource function get address/number() returns int? {
        return 221;
    }

    resource function get address/street() returns string? {
        return "Main Street";
    }

    @graphql:ResourceConfig {
        interceptors: new ErrorInterceptor1()
    }
    resource function get address/city() returns string? {
        return "London";
    }
}

@graphql:ServiceConfig {
    interceptors: new RecordInterceptor1()
}
service /interceptors_with_null_values1 on basicListener {
    resource function get name() returns string? {
        return;
    }
}

@graphql:ServiceConfig {
    interceptors: new NullReturn1()
}
service /interceptors_with_null_values2 on basicListener {
    resource function get name() returns string? {
        return "Ballerina";
    }

    @graphql:ResourceConfig {
        interceptors: new NullReturn2()
    }
    resource function get age() returns int? {
        return 44;
    }
}

@graphql:ServiceConfig {
    interceptors: new NullReturn1()
}
service /interceptors_with_null_values3 on basicListener {
    resource function get name() returns string {
        return "Ballerina";
    }

    @graphql:ResourceConfig {
        interceptors: new NullReturn2()
    }
    resource function get age() returns int {
        return 44;
    }
}

const GRAPHQL_TRANSPORT_WS = "graphql-transport-ws";

public enum Weekday {
    SUNDAY,
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY
}

public type Address readonly & record {
    string number;
    string street;
    string city;
};

public type Person readonly & record {
    string name;
    int age?;
    Address address;
};

public type Book readonly & record {
    string name;
    string author;
};

public type Contact readonly & record {
    string number;
};

public type Languages record {|
    map<string> name;
|};


public type PeopleService StudentService|TeacherService;


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

final readonly & EmployeeTable employees = table[
    { id: 1, name: "John Doe", salary: 1000.00 },
    { id: 2, name: "Jane Doe", salary: 2000.00 },
    { id: 3, name: "Johnny Roe", salary: 500.00 }
];


public distinct isolated service class Customer {
    private final int id;
    private final string name;

    public isolated function init(int id, string name) {
        self.id = id;
        self.name = name;
    }

    @graphql:ResourceConfig {
        interceptors: [new Counter(), new Counter(), new Counter()]
    }
    isolated resource function get id() returns int {
        return self.id;
    }

    @graphql:ResourceConfig {
        interceptors: new NullReturn1()
    }
    isolated resource function get name() returns string? {
        lock {
            return self.name;
        }
    }

    isolated resource function get address() returns CustomerAddress {
        return new (225, "Bakers street", "London");
    }
}

public distinct isolated service class CustomerAddress {
    private final int number;
    private final string street;
    private final string city;

    public isolated function init(int number, string street, string city) {
        self.number = number;
        self.street = street;
        self.city = city;
    }

    @graphql:ResourceConfig {
        interceptors: [new Counter(), new Counter()]
    }
    isolated resource function get number() returns int {
        return self.number;
    }

    @graphql:ResourceConfig {
        interceptors: new Street()
    }
    isolated resource function get street() returns string {
        return self.street;
    }

    @graphql:ResourceConfig {
        interceptors: new City()
    }
    isolated resource function get city() returns string {
        return self.city;
    }
}

final readonly & Person p2 = {
    name: "Walter White",
    age: 50,
    address: a2
};

type EmployeeTable table<Employee> key(id);

final readonly & Address a2 = {
    number: "308",
    street: "Negra Arroyo Lane",
    city: "Albuquerque"
};


type Employee readonly & record {|
    readonly int id;
    string name;
    decimal salary;
|};

@graphql:ServiceConfig {
    interceptors: [new InvalidInterceptor1(), new InvalidInterceptor2()]
}
service /invalid_interceptor1 on basicListener {
    @graphql:ResourceConfig {
        interceptors: [new InvalidInterceptor8(), new InvalidInterceptor9()]
    }
    isolated resource function get age() returns int {
        return 23;
    }
}

@graphql:ServiceConfig {
    interceptors: [new InvalidInterceptor3(), new InvalidInterceptor4()]
}
service /invalid_interceptor2 on basicListener {
    @graphql:ResourceConfig {
        interceptors: new InvalidInterceptor8()
    }
    isolated resource function get friends() returns string[] {
        return ["Harry", "Ron", "Hermione"];
    }
}

@graphql:ServiceConfig {
    interceptors: [new InvalidInterceptor5(), new InvalidInterceptor6()]
}
service /invalid_interceptor3 on basicListener {
    @graphql:ResourceConfig {
        interceptors: new InvalidInterceptor9()
    }
    isolated resource function get person() returns Person {
        return {
            name: "Albus Percival Wulfric Brian Dumbledore",
            age: 80,
            address: {number: "101", street: "Mould-on-the-Wold", city: "London"}
        };
    }
}

@graphql:ServiceConfig {
    interceptors: new InvalidInterceptor7()
}
service /invalid_interceptor4 on basicListener {
    @graphql:ResourceConfig {
        interceptors: new InvalidInterceptor9()
    }
    resource function get student() returns StudentService {
        return new StudentService(45, "Ron Weasly");
    }
}


@graphql:ServiceConfig {
    interceptors: [new DestructiveModification()]
}
isolated service /subscription_interceptor6 on subscriptionListener {

    isolated resource function get name() returns string {
        return "Walter White";
    }

    @graphql:ResourceConfig {
        interceptors: new DestructiveModification()
    }
    isolated resource function subscribe messages() returns stream<int, error?> {
        int[] intArray = [1, 2, 3, 4, 5];
        return intArray.toStream();
    }
}


@graphql:ServiceConfig {
    interceptors: new ReturnBeforeResolver()
}
isolated service /subscription_interceptor5 on subscriptionListener {

    isolated resource function get name() returns string {
        return "Walter White";
    }

    isolated resource function subscribe messages() returns stream<int, error?> {
        int[] intArray = [1, 2, 3, 4, 5];
        return intArray.toStream();
    }
}


@graphql:ServiceConfig {
    interceptors: [new Subtraction(), new Multiplication()]
}
isolated service /subscription_interceptor1 on subscriptionListener {

    isolated resource function get name() returns string {
        return "Walter White";
    }

    @graphql:ResourceConfig {
        interceptors: [new Subtraction(), new Multiplication()]
    }
    isolated resource function subscribe messages() returns stream<int, error?> {
        int[] intArray = [1, 2, 3, 4, 5];
        return intArray.toStream();
    }
}

@graphql:ServiceConfig {
    interceptors: [new InterceptAuthor(), new ServiceLevelInterceptor()]
}
isolated service /subscription_interceptor2 on subscriptionListener {

    isolated resource function get name() returns string {
        return "Walter White";
    }

    isolated resource function subscribe books() returns stream<Book?, error?> {
        Book?[] books = [
            {name: "Crime and Punishment", author: "Fyodor Dostoevsky"},
            {name: "A Game of Thrones", author: "George R.R. Martin"},
            ()
        ];
        return books.toStream();
    }

    @graphql:ResourceConfig {
        interceptors: [new InterceptBook()]
    }
    isolated resource function subscribe newBooks() returns stream<Book?, error?> {
        Book?[] books = [
            {name: "Crime and Punishment", author: "Fyodor Dostoevsky"},
            ()
        ];
        return books.toStream();
    }
}

@graphql:ServiceConfig {
    interceptors: new InterceptStudentName()
}
isolated service /subscription_interceptor3 on subscriptionListener {

    isolated resource function get name() returns string {
        return "Walter White";
    }

    isolated resource function subscribe students() returns stream<StudentService, error?> {
        StudentService[] students = [new StudentService(1, "Eren Yeager"), new StudentService(2, "Mikasa Ackerman")];
        return students.toStream();
    }

    @graphql:ResourceConfig {
        interceptors: [new InterceptStudent()]
    }
    isolated resource function subscribe newStudents() returns stream<StudentService, error?> {
        StudentService[] students = [new StudentService(1, "Eren Yeager"), new StudentService(2, "Mikasa Ackerman")];
        return students.toStream();
    }
}

@graphql:ServiceConfig {
    interceptors: new InterceptUnionType1()
}
isolated service /subscription_interceptor4 on subscriptionListener {

    isolated resource function get name() returns string {
        return "Walter White";
    }

    isolated resource function subscribe multipleValues1() returns stream<PeopleService>|error {
        StudentService s = new StudentService(1, "Jesse Pinkman");
        TeacherService t = new TeacherService(0, "Walter White", "Chemistry");
        return [s, t].toStream();
    }

    @graphql:ResourceConfig {
        interceptors: new InterceptUnionType2()
    }
    isolated resource function subscribe multipleValues2() returns stream<PeopleService>|error {
        StudentService s = new StudentService(1, "Harry Potter");
        TeacherService t = new TeacherService(3, "Severus Snape", "Dark Arts");
        return [s, t].toStream();
    }
}
