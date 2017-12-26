# dackson

Dackson is a loose port Java's Jackson library for serializing and deserializing JSON data into user-defined data structures.

# Installation

Dub is not yet included on the DUB package registry. Users must clone this repository and add it as a local repository:

```
git clone git@github.com:leeavital/dackson.git
cd dackson
dub add-local $PWD
```

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

