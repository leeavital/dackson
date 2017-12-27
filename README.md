# dackson

[![Build Status](https://travis-ci.org/leeavital/dackson.svg?branch=master)](https://travis-ci.org/leeavital/dackson)

Dackson is a loose port Java's Jackson library for serializing and deserializing JSON data into user-defined data structures.

# Installation

Dackson is published on the [DUB package registry](http://code.dlang.org/packages/dackson).

# Deserializing

To deserialize a datatype, you must first define it! Dackson will work with any
mutable struct, though you can add additional `JsonProperty` annotations if the
D field name differs from the actual field name.

```D
import dackson;

struct User {
  @JsonProperty("user_id") long userId;
  string username;
}
```

Then use the `decodeJson` function to decode the JSON (in string form) into a D type.

```D
string json = `{"user_id": 1234, "username": "John Smith"}`;
User u = decodeJson!(User)(json);  // User(1234, "John Smith")
```

Or use unified function call syntax: 

```D
string json = `{"user_id": 1234, "username": "John Smith"}`;
User u = json.decodeJson!User;  // User(1234, "John Smith")
```

# Serializing

Encode using the `encodeJson` function. The `JsonProperty` annotations will be respected.

```D
import dackson;

struct User {
  @JsonProperty("user_id") long userId;
  string username;
}

string encoded = encodeJson(User(1234, "John Smith")); // {"user_id":1234,"username":"John Smith"}
```

# Future Work

- Support for classes and immutable structures.
- `@JsonIgnore` annotations
- Special behavior for missing/null values
