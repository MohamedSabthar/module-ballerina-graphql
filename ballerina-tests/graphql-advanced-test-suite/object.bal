import ballerina/graphql;

public type Device distinct service object {
    isolated resource function get id() returns @graphql:ID int;

    @graphql:ResourceConfig {
        complexity: 1
    }
    isolated resource function get brand() returns string;

    isolated resource function get model() returns string;

    @graphql:ResourceConfig {
        complexity: 4
    }
    isolated resource function get price() returns float;
};

public isolated distinct service class Phone {
    *Device;

    private final int id;
    private final string brand;
    private final string model;
    private final float price;
    private final OS os;
    private final Device[] connectedDevices;

    isolated function init(int id, string brand, string model, float price, OS os) {
        self.id = id;
        self.brand = brand;
        self.model = model;
        self.price = price;
        self.os = os;
    }

    isolated resource function get id() returns @graphql:ID int => self.id;

    isolated resource function get brand() returns string => self.brand;

    isolated resource function get model() returns string => self.model;

    isolated resource function get price() returns float => self.price;

    isolated resource function get os() returns OS => self.os;
}

public isolated distinct service class Laptop {
    *Device;

    private final int id;
    private final string brand;
    private final string model;
    private final float price;
    private final string processor;
    private final int ram;

    isolated function init(int id, string brand, string model, float price, string processor, int ram) {
        self.id = id;
        self.brand = brand;
        self.model = model;
        self.price = price;
        self.processor = processor;
        self.ram = ram;
    }

    isolated resource function get id() returns @graphql:ID int => self.id;

    isolated resource function get brand() returns string => self.brand;

    isolated resource function get model() returns string => self.model;

    isolated resource function get price() returns float => self.price;

    isolated resource function get processor() returns string => self.processor;

    isolated resource function get ram() returns int => self.ram;
}

public isolated distinct service class Tablet {
    *Device;

    private final int id;
    private final string brand;
    private final string model;
    private final float price;
    private final boolean hasCellular;

    isolated function init(int id, string brand, string model, float price, boolean hasCellular) {
        self.id = id;
        self.brand = brand;
        self.model = model;
        self.price = price;
        self.hasCellular = hasCellular;
    }

    isolated resource function get id() returns @graphql:ID int => self.id;

    isolated resource function get brand() returns string => self.brand;

    isolated resource function get model() returns string => self.model;

    isolated resource function get price() returns float => self.price;

    isolated resource function get hasCellular() returns boolean => self.hasCellular;
}

type RatingInput readonly & record {|
    string title;
    int stars;
    string description;
    int authorId;
|};


service class Rating {
    private final RatingData data;

    isolated function init(RatingData data) {
        self.data = data;
    }

    isolated resource function get id() returns @graphql:ID int => self.data.id;

    @graphql:ResourceConfig {
        complexity: 1
    }
    isolated resource function get title() returns string => self.data.title;

    @graphql:ResourceConfig {
        complexity: 1
    }
    isolated resource function get stars() returns int => self.data.stars;

    isolated resource function get description() returns string => self.data.description;

    @graphql:ResourceConfig {
        complexity: 10
    }
    isolated resource function get author() returns DeviceUserProfile|error {
        lock {
            if profileTable.hasKey(self.data.authorId) {
                return new DeviceUserProfile(profileTable.get(self.data.authorId));
            }
        }
        return error("Author not found");
    }
}

type RatingData readonly & record {|
    readonly int id;
    string title;
    int stars;
    string description;
    int authorId;
|};

isolated table<RatingData> key(id) ratingTable = table [
    {id: 1, title: "Good", stars: 4, description: "Good product", authorId: 1},
    {id: 2, title: "Bad", stars: 2, description: "Bad product", authorId: 2},
    {id: 3, title: "Excellent", stars: 5, description: "Excellent product", authorId: 3},
    {id: 4, title: "Poor", stars: 1, description: "Poor product", authorId: 4}
];

type Mobile Phone|Tablet;


service class DeviceUserProfile {
    private final DeviceUserProfileData data;

    isolated function init(DeviceUserProfileData data) {
        self.data = data;
    }

    isolated resource function get id() returns @graphql:ID int => self.data.id;

    isolated resource function get name() returns string => self.data.name;

    isolated resource function get age() returns int => self.data.age;
}

isolated table<DeviceUserProfileData> key(id) profileTable = table [
    {id: 1, name: "Alice", age: 25},
    {id: 2, name: "Bob", age: 30},
    {id: 3, name: "Charlie", age: 35},
    {id: 4, name: "David", age: 40}
];


type DeviceUserProfileData readonly & record {|
    readonly int id;
    string name;
    int age;
|};

enum OS {
    iOS,
    Android,
    Windows
}
