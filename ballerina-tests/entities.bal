// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

import ballerina/graphql.subgraph;

@subgraph:Entity {
    key: "name",
    resolveReference: isolated function(subgraph:Representation representation) returns Star|error {
        string name = check representation["name"].ensureType();
        return findStarByName(name);
    }
}
distinct service class Star {
    private StarInfo starInfo;

    isolated function init(StarInfo starInfo) {
        self.starInfo = starInfo;
    }

    resource function get name() returns string {
        return self.starInfo.name;
    }

    resource function get constellation() returns string {
        return self.starInfo.name;
    }

    resource function get designation() returns string {
        return self.starInfo.designation;
    }

    public function getName() returns string {
        return self.starInfo.name;
    }
}

type StarInfo record {
    string name;
    string constellation;
    string designation;
};

final readonly & StarInfo[] stars = [
    {name: "Absolutno*", constellation: "Lynx", designation: "XO-5"},
    {name: "Acamar", constellation: "Eridanus", designation: "θ1 Eridani A"},
    {name: "Achernar", constellation: "Eridanus", designation: "α Eridani A"}
];

isolated function findStarByName(string name) returns Star|error {
    StarInfo startInfo = check trap stars.filter(star => star.name == name).shift();  
    return new (startInfo); 
}

@subgraph:Entity {
    key: ["name", "id"],
    resolveReference: isolated function(subgraph:Representation representation) returns Planet? {
        do {
            string name = check representation["name"].ensureType();
            return check findPlanetByName(name);
        } on fail {
            return ();
        }
    }
}
public type Planet record {
    int id;
    string name;
    decimal mass;
    int numberOfMoons;
    Moon moon?;
};

final readonly & Planet[] planets = [
    {id: 1, name: "Mercury", mass: 0.383, numberOfMoons: 0},
    {id: 2, name: "Venus", mass: 0.949, numberOfMoons: 0},
    {id: 3, name: "Earth", mass: 1, numberOfMoons: 1, moon: {name: "moon"}}
];

isolated function findPlanetByName(string name) returns Planet|error {
    return trap planets.filter(planet => planet.name == name).shift();
}

@subgraph:Entity {
    key: "name",
    resolveReference: ()
}
public type Moon record {
    string name;
};

// This entity has invalid resolveReference return type - (ie. doesn't return Satellite)
@subgraph:Entity {
    key: "name",
    resolveReference: isolated function(subgraph:Representation representation) returns record {} {
        return {};
    }
}
public type Satellite record {
    string name;
    int MissionDuration;
};

@subgraph:Entity {
    key: "id",
    resolveReference: isolated function(subgraph:Representation representation) returns ProductData|error? {
        // Dummy logic to resolve product
        return {id: check representation["id"].ensureType(), reviews: [new]};
    }
}
public type ProductData record {
    readonly string id;
    ReviewData[] reviews;
};
