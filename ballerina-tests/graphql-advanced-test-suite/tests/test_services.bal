import ballerina/graphql;
import ballerina/http;
import ballerina/graphql_test_common as common;
import ballerina/constraint;

listener graphql:Listener serviceTypeListener = new (9092);
listener graphql:Listener basicListener = new (9091);
listener graphql:Listener graphqlListener = new (9098);

@graphql:ServiceConfig {
    contextInit:
    isolated function(http:RequestContext requestContext, http:Request request) returns graphql:Context|error {
        graphql:Context context = new;
        context.set("scope", check request.getHeader("scope"));
        return context;
    }
}
service /context on serviceTypeListener {
    isolated resource function get profile(graphql:Context context) returns Person|error {
        var scope = check context.get("scope");
        if scope is string && scope == "admin" {
            return {
                name: "Walter White",
                age: 51,
                address: {
                    number: "308",
                    street: "Negra Arroyo Lane",
                    city: "Albuquerque"
                }
            };
        } else {
            return error("You don't have permission to retrieve data");
        }
    }

    isolated resource function get name(graphql:Context context, string name) returns string|error {
        var scope = check context.get("scope");
        if scope is string && scope == "admin" {
            return name;
        } else {
            return error("You don't have permission to retrieve data");
        }
    }

    isolated resource function get animal() returns AnimalClass {
        return new;
    }

    remote function update(graphql:Context context) returns (Person|error)[]|error {
        var scope = check context.get("scope");
        if scope is string && scope == "admin" {
            return people;
        } else {
            return [p1, error("You don't have permission to retrieve data"), p3];
        }
    }

    remote function updateNullable(graphql:Context context) returns (Person|error?)[]|error {
        var scope = check context.get("scope");
        if scope is string && scope == "admin" {
            return people;
        } else {
            return [p1, error("You don't have permission to retrieve data"), p3];
        }
    }
}

service /fileUpload on basicListener {
    resource function get name() returns string {
        return "/fileUpload";
    }

    remote function singleFileUpload(graphql:Upload file) returns FileInfo|error {
        string contentFromByteStream = check common:getContentFromByteStream(file.byteStream);
        return {
            fileName: file.fileName,
            mimeType: file.mimeType,
            encoding: file.encoding,
            content: contentFromByteStream
        };
    }

    remote function multipleFileUpload(graphql:Upload[] files) returns FileInfo[]|error {
        FileInfo[] fileInfo = [];
        foreach int i in 0 ..< files.length() {
            graphql:Upload file = files[i];
            string contentFromByteStream = check common:getContentFromByteStream(file.byteStream);
            fileInfo.push({
                fileName: file.fileName,
                mimeType: file.mimeType,
                encoding: file.encoding,
                content: contentFromByteStream
            });
        }
        return fileInfo;
    }
}

service /service_types on serviceTypeListener {
    isolated resource function get greet() returns GeneralGreeting {
        return new;
    }

    isolated resource function get profile() returns Profile {
        return new;
    }

    isolated resource function get person(graphql:Field 'field) returns Person {
        string[] subfieldNames = 'field.getSubfieldNames();
        if subfieldNames == ["name"] {
            return {
                name: "Sherlock Holmes",
                address: {number: "221/B", street: "Baker Street", city: "London"}
            };
        } else if subfieldNames == ["name", "age"] {
            return {
                name: "Walter White",
                age: 50,
                address: {number: "309", street: "Negro Arroyo Lane", city: "Albuquerque"}
            };
        }
        return {
            name: "Jesse Pinkman",
            age: 25,
            address: {number: "208", street: "Margo Street", city: "Albuquerque"}
        };
    }
}

service /service_objects on serviceTypeListener {
    isolated resource function get ids() returns int[] {
        return [0, 1, 2];
    }

    isolated resource function get allVehicles() returns Vehicle[] {
        Vehicle v1 = new ("V1", "Benz", 2005);
        Vehicle v2 = new ("V2", "BMW", 2010);
        Vehicle v3 = new ("V3", "Ford");
        return [v1, v2, v3];
    }

    isolated resource function get searchVehicles(string keyword) returns Vehicle[]? {
        Vehicle v1 = new ("V1", "Benz");
        Vehicle v2 = new ("V2", "BMW");
        Vehicle v3 = new ("V3", "Ford");
        return [v1, v2, v3];
    }

    isolated resource function get teacher() returns TeacherService {
        return new TeacherService(737, "Walter White", "Chemistry");
    }

    isolated resource function get student(string name, graphql:Context context, int id,
            graphql:Field 'field) returns StudentService {
        if context.get("scope") is error {
            // ignore
        }
        if 'field.getSubfieldNames().indexOf("id") is int {
            return new StudentService(id, name);
        }
        return new StudentService(10, "Jesse Pinkman");
    }
}

service /constraints on basicListener {

    private string[] movies;

    isolated function init() {
        self.movies = [];
    }

    isolated resource function get movie(MovieDetails movie) returns string {
        return movie.name;
    }

    isolated resource function get movies(MovieDetails[] & readonly movies) returns string[] {
        return movies.map(m => m.name);
    }

    isolated resource function get reviewStars(Reviews[] reviews) returns int[] {
        return reviews.map(r => r.stars);
    }

    isolated remote function addMovie(MovieDetails movie) returns string {
        string name = movie.name;
        self.movies.push(name);
        return name;
    }
}

@graphql:ServiceConfig {
    validation: false
}
service /constraints_config on basicListener {

    isolated resource function get movie(MovieDetails movie) returns string {
        return movie.name;
    }
}

service /server_cache on basicListener {
    private string name = "Walter White";
    private table<Friend> key(name) friends = table [
        {name: "Skyler", age: 45, isMarried: true},
        {name: "Walter White Jr.", age: 57, isMarried: true},
        {name: "Jesse Pinkman", age: 23, isMarried: false}
    ];

    private table<Enemy> key(name) enemies = table [
        {name: "Enemy1", age: 12, isMarried: false},
        {name: "Enemy2", age: 66, isMarried: true},
        {name: "Enemy3", age: 33, isMarried: false}
    ];

    isolated resource function get greet() returns string {
        return "Hello, " + self.name;
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            enabled: true
        }
    }
    isolated resource function get isAdult(int? age) returns boolean|error {
        if age is int {
            return age >= 18 ? true : false;
        }
        return error("Invalid argument type");
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            enabled: true
        }
    }
    isolated resource function get name(int id) returns string {
        return self.name;
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            maxAge: 120
        }
    }
    isolated resource function get friends(boolean isMarried = false) returns Friend[] {
        if isMarried {
            return from Friend friend in self.friends
                where friend.isMarried == true
                select friend;
        }
        return from Friend friend in self.friends
            where friend.isMarried == false
            select friend;
    }

    isolated resource function get getFriendService(string name) returns FriendService {
        Friend[] person = from Friend friend in self.friends
            where friend.name == name
            select friend;
        return new FriendService(person[0].name, person[0].age, person[0].isMarried);
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            maxAge: 180
        }
    }
    isolated resource function get getFriendServices() returns FriendService[] {
        return from Friend friend in self.friends
            select new FriendService(friend.name, friend.age, friend.isMarried);
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            maxAge: 180
        }
    }
    isolated resource function get getServices(boolean isEnemy) returns HumanService[] {
        if isEnemy {
            return from Friend friend in self.friends
                where friend.isMarried == false
                select new EnemyService(friend.name, friend.age, friend.isMarried);
        }
        return from Friend friend in self.friends
            where friend.isMarried == true
            select new FriendService(friend.name, friend.age, friend.isMarried);
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            maxAge: 120
        }
    }
    isolated resource function get enemies(boolean? isMarried = ()) returns Enemy[] {
        if isMarried is () {
            return from Enemy enemy in self.enemies
                select enemy;
        }
        return from Enemy enemy in self.enemies
            where enemy.isMarried == isMarried
            select enemy;
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            enabled: true
        }
    }
    isolated resource function get isAllMarried(string[] names) returns boolean {
        if names is string[] {
            foreach string name in names {
                if self.enemies.hasKey(name) && !self.enemies.get(name).isMarried {
                    return false;
                }
            }
        }
        return true;
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            enabled: true
        }
    }
    isolated resource function get searchEnemy(EnemyInput enemyInput) returns Enemy? {
        if self.enemies.hasKey(enemyInput.name) {
            return self.enemies.get(enemyInput.name);
        }
        return;
    }

    isolated remote function updateName(graphql:Context context, string name, boolean enableEvict) returns string|error {
        if enableEvict {
            check context.invalidate("name");
        }
        self.name = name;
        return self.name;
    }

    isolated remote function updateFriend(graphql:Context context, string name, int age, boolean isMarried, boolean enableEvict) returns FriendService|error {
        if enableEvict {
            check context.invalidateAll();
        }
        self.friends.put({name: name, age: age, isMarried: isMarried});
        return new FriendService(name, age, isMarried);
    }

    isolated remote function addFriend(string name, int age, boolean isMarried) returns Friend {
        Friend friend = {name: name, age: age, isMarried: isMarried};
        self.friends.add(friend);
        return friend;
    }

    isolated remote function addEnemy(graphql:Context context, string name, int age, boolean isMarried, boolean enableEvict) returns Friend|error {
        if enableEvict {
            check context.invalidate("getServices");
        }
        Friend friend = {name: name, age: age, isMarried: isMarried};
        self.friends.add(friend);
        return friend;
    }

    isolated remote function addEnemy2(graphql:Context context, string name, int age, boolean isMarried, boolean enableEvict) returns Enemy|error {
        if enableEvict {
            check context.invalidate("enemies");
        }
        Enemy enemy = {name: name, age: age, isMarried: isMarried};
        self.enemies.add(enemy);
        return enemy;
    }

    isolated remote function removeEnemy(graphql:Context context, string name, boolean enableEvict) returns Enemy|error {
        if enableEvict {
            check context.invalidate("enemies");
        }
        return self.enemies.remove(name);
    }

    isolated remote function updateEnemy(graphql:Context context, EnemyInput enemy, boolean enableEvict) returns Enemy|error {
        if enableEvict {
            check context.invalidateAll();
        }
        Enemy enemyInput = {name: enemy.name, age: enemy.age, isMarried: true};
        self.enemies.put(enemyInput);
        return enemyInput;
    }
}

@graphql:ServiceConfig {
    cacheConfig: {
        enabled: true,
        maxAge: 20,
        maxSize: 15
    }
}
service /server_cache_operations on basicListener {
    private string name = "Walter White";
    private table<Friend> key(name) friends = table [
        {name: "Skyler", age: 45, isMarried: true},
        {name: "Walter White Jr.", age: 57, isMarried: true},
        {name: "Jesse Pinkman", age: 23, isMarried: false}
    ];

    private table<Associate> key(name) associates = table [
        {name: "Gus Fring", status: "dead"},
        {name: "Tuco Salamanca", status: "dead"},
        {name: "Saul Goodman", status: "alive"}
    ];

    isolated resource function get greet() returns string {
        return "Hello, " + self.name;
    }

    isolated resource function get name(int id) returns string {
        return self.name;
    }

    isolated resource function get friends(boolean isMarried = false) returns Friend[] {
        if isMarried {
            return from Friend friend in self.friends
                where friend.isMarried == true
                select friend;
        }
        return from Friend friend in self.friends
            where friend.isMarried == false
            select friend;
    }

    isolated resource function get getFriendService(string name) returns FriendService|error {
        Friend[] person = from Friend friend in self.friends
            where friend.name == name
            select friend;
        if person != [] {
            return new FriendService(person[0].name, person[0].age, person[0].isMarried);
        } else {
            return error(string `No person found with the name: ${name}`);
        }
    }

    isolated resource function get getAssociateService(string name) returns AssociateService {
        Associate[] person = from Associate associate in self.associates
            where associate.name == name
            select associate;
        return new AssociateService(person[0].name, person[0].status);
    }

    isolated resource function get relationship(string name) returns Relationship {
        (Associate|Friend)[] person = from Associate associate in self.associates
            where associate.name == name
            select associate;
        if person.length() == 0 {
            person = from Friend friend in self.friends
                where friend.name == name
                select friend;
            return new FriendService(person[0].name, (<Friend>person[0]).age, (<Friend>person[0]).isMarried);
        }
        return new AssociateService(person[0].name, (<Associate>person[0]).status);
    }

    isolated resource function get getFriendServices() returns FriendService[] {
        return from Friend friend in self.friends
            select new FriendService(friend.name, friend.age, friend.isMarried);
    }

    isolated resource function get getAllFriendServices(graphql:Context context, boolean enableEvict) returns FriendService[]|error {
        if enableEvict {
            check context.invalidateAll();
        }
        return from Friend friend in self.friends
            select new FriendService(friend.name, friend.age, friend.isMarried);
    }

    isolated remote function updateName(graphql:Context context, string name, boolean enableEvict) returns string|error {
        if enableEvict {
            check context.invalidateAll();
        }
        self.name = name;
        return self.name;
    }

    isolated remote function updateFriend(graphql:Context context, string name, int age, boolean isMarried, boolean enableEvict) returns FriendService|error {
        if enableEvict {
            check context.invalidateAll();
        }
        self.friends.put({name: name, age: age, isMarried: isMarried});
        return new FriendService(name, age, isMarried);
    }

    isolated remote function updateAssociate(graphql:Context context, string name, string status, boolean enableEvict) returns AssociateService|error {
        if enableEvict {
            check context.invalidateAll();
        }
        self.associates.put({name: name, status: status});
        return new AssociateService(name, status);
    }

    isolated remote function addFriend(graphql:Context context, string name, int age, boolean isMarried, boolean enableEvict) returns Friend|error {
        if enableEvict {
            check context.invalidate("getFriendService");
            check context.invalidate("getAllFriendServices");
            check context.invalidate("friends");
        }
        Friend friend = {name: name, age: age, isMarried: isMarried};
        self.friends.add(friend);
        return friend;
    }

    resource function get status(Associate[]? associates) returns string[]? {
        if associates is Associate[] {
            return associates.map(associate => associate.status);
        }
        return;
    }
}


@graphql:ServiceConfig {
    cacheConfig: {
        maxSize: 5
    }
}
service /server_cache_records_with_non_optional on basicListener {
    private table<ProfileInfo> profiles = table [
        {name: "John", age: 30, contact: "0123456789"},
        {name: "Doe", age: 25, contact: "9876543210"},
        {name: "Jane", age: 35, contact: "1234567890"}
    ];

    resource function get profiles() returns ProfileInfo[] {
        return self.profiles.toArray();
    }

    remote function removeProfiles(graphql:Context ctx, boolean enableEvict) returns ProfileInfo[]|error {
        if enableEvict {
            check ctx.invalidateAll();
        }
        ProfileInfo[] profiles = self.profiles.toArray();
        self.profiles.removeAll();
        return profiles;
    }
}


service /field_caching_with_ttl on basicListener {
    private string enemy = "voldemort";
    private string friend = "Harry";

    @graphql:ResourceConfig {
        cacheConfig: {
            enabled: true,
            maxAge: 10
        }
    }
    resource function get friend() returns string {
        return self.friend;
    }
    
    remote function updateFriend(string name) returns string|error {
        self.friend = name;
        return self.friend;
    }
}


service /dynamic_response on basicListener {
    private User user = {id: 1, name: "John", age: 25};

    @graphql:ResourceConfig {
        cacheConfig: {
            enabled: true,
            maxAge: 600
        }
    }
    resource function get user(graphql:Field 'field, int id) returns User {
        string[] sub = 'field.getSubfieldNames();
        if sub.length() == 1 {
            return {id: self.user.id};
        } else if sub.length() == 2 {
            return {id: self.user.id, name: self.user.name};
        } else {
            return self.user;
        }
    }

    remote function updateUser(graphql:Context context, int id, string name, int age, boolean enableEvict) returns User|error {
        if enableEvict {
            check context.invalidate("user");
        }
        self.user = {id: id, name: name, age: age};
        return self.user;
    }
}

@graphql:ServiceConfig {
    cacheConfig: {
        maxAge: 600
    }
}
service /cache_with_list_input on basicListener {
    private User user1 = {id: 1, name: "John", age: 25};
    private User user2 = {id: 2, name: "Jessie", age: 17};
    private Address[] addresses = [];

    resource function get users1(int[] ids) returns User[] {
        if ids.length() == 1 && ids[0] == 1 {
            return [self.user1];
        } else if ids.length() == 1 && ids[0] == 2 {
            return [self.user2];
        }
        return [self.user1, self.user2];
    }

    resource function get users2(int[][] ids) returns User[] {
        if ids.length() == 3 && ids[0][0] == 1 {
            return [self.user1];
        } else if ids.length() == 3 && ids[0][0] == 2 || ids[0][0] == 3 {
            return [self.user2];
        }
        return [self.user1, self.user2];
    }

    resource function get cities(Address[] addresses) returns string[] {
        self.addresses.push(...addresses);
        return self.addresses.map(address => address.city);
    }

    remote function updateUser(int id, string name, int age) returns User|error {
        self.user1 = {id: id, name: name, age: age};
        return self.user1;
    }

    remote function updateAddress(Address address) returns Address {
        self.addresses.push(address);
        return address;
    }
}

@graphql:ServiceConfig {
    queryComplexityConfig: {
        maxComplexity: 20,
        defaultFieldComplexity: 2
    }
}
service /complexity on graphqlListener {
    resource function get greeting() returns string {
        return "Hello";
    }

    @graphql:ResourceConfig {
        complexity: 10
    }
    resource function get device(int id) returns Device {
        if id < 10 {
            return new Phone(id, "Apple", "iPhone 15 Pro", 1199.00, "iOS");
        }

        if id < 20 {
            return new Laptop(id, "Apple", "MacBook Pro", 2399.00, "M1", 32);
        }

        return new Tablet(id, "Samsung", "Galaxy Tab S7", 649.99, true);
    }

    @graphql:ResourceConfig {
        complexity: 5
    }
    resource function get mobile(int id) returns Mobile {
        if id < 10 {
            return new Phone(id, "Apple", "iPhone 15 Pro", 1199.00, "iOS");
        }

        return new Tablet(id, "Samsung", "Galaxy Tab S7", 649.99, true);
    }

    @graphql:ResourceConfig {
        complexity: 15
    }
    remote function addReview(RatingInput input) returns Rating {
        lock {
            int id = ratingTable.length();
            RatingData rating = {
                id,
                ...input
            };
            ratingTable.put(rating);
            return new (rating);
        }
    }
}

public distinct isolated service class HierarchicalName {
    isolated resource function get name/first() returns string {
        return "Sherlock";
    }

    isolated resource function get name/last() returns string {
        return "Holmes";
    }
}

public type Person readonly & record {
    string name;
    int age?;
    Address address;
};

public isolated distinct service class AnimalClass {
    isolated resource function get call(graphql:Context context, string sound, int count) returns string {
        var scope = context.get("scope");
        if scope is string && scope == "admin" {
            string call = "";
            int i = 0;
            while i < count {
                call += string `${sound} `;
                i += 1;
            }
            return call;
        } else {
            return sound;
        }
    }
}

final readonly & Person[] people = [p1, p2, p3];

final readonly & Person p1 = {
    name: "Sherlock Holmes",
    age: 40,
    address: a1
};

final readonly & Person p2 = {
    name: "Walter White",
    age: 50,
    address: a2
};

final readonly & Person p3 = {
    name: "Tom Marvolo Riddle",
    age: 100,
    address: a3
};


public type FileInfo record {
    string fileName;
    string mimeType;
    string encoding;
    string content;
};

public isolated service class GeneralGreeting {
    isolated resource function get generalGreeting() returns string {
        return "Hello, world";
    }
}

public isolated service class Profile {
    isolated resource function get name() returns Name {
        return new;
    }
}

public isolated service class Vehicle {
    private final string id;
    private final string name;
    private final int? registeredYear;

    isolated function init(string id, string name, int? registeredYear = ()) {
        self.id = id;
        self.name = name;
        self.registeredYear = registeredYear;
    }

    isolated resource function get id() returns string {
        return self.id;
    }

    isolated resource function get name() returns string {
        return self.name;
    }

    isolated resource function get registeredYear() returns int|error {
        int? registeredYear = self.registeredYear;
        if registeredYear == () {
            return error("Registered Year is Not Found");
        } else {
            return registeredYear;
        }
    }
}

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

type Friend record {|
    readonly string name;
    int age;
    boolean isMarried;
|};

type Enemy record {|
    readonly string name;
    int age;
    boolean isMarried;
|};

public type HumanService FriendService|EnemyService;

public isolated distinct service class FriendService {
    private final string name;
    private final int age;
    private final boolean isMarried;

    public isolated function init(string name, int age, boolean isMarried) {
        self.name = name;
        self.age = age;
        self.isMarried = isMarried;
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            maxAge: 180
        }
    }
    isolated resource function get name() returns string {
        return self.name;
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            maxAge: 180
        }
    }
    isolated resource function get age() returns int {
        return self.age;
    }

    @graphql:ResourceConfig {
        cacheConfig: {
            maxAge: 180
        }
    }
    isolated resource function get isMarried() returns boolean {
        return self.isMarried;
    }
}

public isolated distinct service class EnemyService {
    private final string name;
    private final int age;
    private final boolean isMarried;

    public isolated function init(string name, int age, boolean isMarried) {
        self.name = name;
        self.age = age;
        self.isMarried = isMarried;
    }

    isolated resource function get name() returns string {
        return self.name;
    }

    isolated resource function get age() returns int {
        return self.age;
    }

    isolated resource function get isMarried() returns boolean {
        return self.isMarried;
    }
}

type Associate record {|
    readonly string name;
    string status;
|};

type EnemyInput record {|
    readonly string name = "Enemy6";
    int age = 12;
|};

public isolated distinct service class AssociateService {
    private final string name;
    private final string status;

    public isolated function init(string name, string status) {
        self.name = name;
        self.status = status;
    }

    isolated resource function get name() returns string {
        return self.name;
    }

    isolated resource function get status() returns string {
        return self.status;
    }
}

public type Relationship FriendService|AssociateService;


type ProfileInfo record {|
    string name;
    int age;
    string contact;
|};

type User record {|
    int id?;
    string name?;
    int age?;
|};

public type Address readonly & record {
    string number;
    string street;
    string city;
};

final readonly & Address a1 = {
    number: "221/B",
    street: "Baker Street",
    city: "London"
};

final readonly & Address a2 = {
    number: "308",
    street: "Negra Arroyo Lane",
    city: "Albuquerque"
};

final readonly & Address a3 = {
    number: "Uknown",
    street: "Unknown",
    city: "Hogwarts"
};

public isolated service class Name {
    isolated resource function get first() returns string {
        return "Sherlock";
    }

    isolated resource function get last() returns string {
        return "Holmes";
    }

    isolated resource function get surname() returns string|error {
        return error("No surname found");
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
