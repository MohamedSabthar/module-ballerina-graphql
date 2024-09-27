// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/graphql;

listener graphql:Listener basicListener = new (9091);
listener graphql:Listener specialTypesTestListener = new (9095);
listener graphql:Listener hierarchicalPathListener = new (9094);

service /inputs on basicListener {
    isolated resource function get greet(string name) returns string {
        return "Hello, " + name;
    }
}


service /special_types on specialTypesTestListener {

    isolated resource function get time() returns Time {
        return {
            weekday: MONDAY,
            time: "22:10:33"
        };
    }

    isolated resource function get specialHolidays() returns (Weekday|error)?[] {
        return [TUESDAY, error("Holiday!"), THURSDAY];
    }
}

service /records on basicListener {
    isolated resource function get detective() returns Person {
        return {
            name: "Sherlock Holmes",
            age: 40,
            address: {number: "221/B", street: "Baker Street", city: "London"}
        };
    }

    isolated resource function get teacher() returns Person {
        return {
            name: "Walter White",
            age: 50,
            address: {number: "308", street: "Negra Arroyo Lane", city: "Albuquerque"}
        };
    }

    isolated resource function get student() returns Person {
        return {
            name: "Jesse Pinkman",
            age: 25,
            address: {number: "9809", street: "Margo Street", city: "Albuquerque"}
        };
    }

    resource function get profile(int id) returns Person|error {
        return trap people[id];
    }

    resource function get people() returns Person[] {
        return people;
    }

    resource function get students() returns Student[] {
        return students;
    }
}

isolated service /mutations on basicListener {
    private Person p;

    isolated function init() {
        self.p = p2.clone();
    }

    isolated resource function get greet(string name) returns string {
        return "Hello, " + name;
    }

    isolated remote function setName(string name) returns Person {
        lock {
            Person p = {name: name, age: self.p.age, address: self.p.address};
            self.p = p;
            return self.p;
        }
    }
}

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


public type Person readonly & record {
    string name;
    int age?;
    Address address;
};

public type Address readonly & record {
    string number;
    string street;
    string city;
};


public type Student readonly & record {
    string name;
    Course[] courses;
};

type Course readonly & record {
    string name;
    int code;
    Book[] books;
};

public type Book readonly & record {
    string name;
    string author;
};


public type Time record {|
    Weekday weekday;
    string time;
|};

public enum Weekday {
    SUNDAY,
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY
}

final readonly & Person[] people = [p1, p2, p3];


final readonly & Student s1 = {
    name: "John Doe",
    courses: [c1, c2]
};

final readonly & Student s2 = {
    name: "Jane Doe",
    courses: [c2, c3]
};

final readonly & Student s3 = {
    name: "Jonny Doe",
    courses: [c1, c2, c3]
};

final readonly & Course c1 = {
    name: "Electronics",
    code: 106,
    books: [b1, b2]
};

final readonly & Course c2 = {
    name: "Computer Science",
    code: 107,
    books: [b3, b4]
};

final readonly & Course c3 = {
    name: "Mathematics",
    code: 105,
    books: [b5, b6]
};

final readonly & Student[] students = [s1, s2, s3];

final readonly & Book b1 = {
    name: "The Art of Electronics",
    author: "Paul Horowitz"
};

final readonly & Book b2 = {
    name: "Practical Electronics",
    author: "Paul Scherz"
};

final readonly & Book b3 = {
    name: "Algorithms to Live By",
    author: "Brian Christian"
};

final readonly & Book b4 = {
    name: "Code: The Hidden Language",
    author: "Charles Petzold"
};

final readonly & Book b5 = {
    name: "Calculus Made Easy",
    author: "Silvanus P. Thompson"
};

final readonly & Book b6 = {
    name: "Calculus",
    author: "Michael Spivak"
};

service /profiles on hierarchicalPathListener {
    isolated resource function get profile/name/first() returns string {
        return "Sherlock";
    }

    isolated resource function get profile/name/last() returns string {
        return "Holmes";
    }

    isolated resource function get profile/age() returns int {
        return 40;
    }

    isolated resource function get profile/address/city() returns string {
        return "London";
    }

    isolated resource function get profile/address/street() returns string {
        return "Baker Street";
    }

    isolated resource function get profile/name/address/number() returns string {
        return "221/B";
    }
}