import std.stdio;

import std.json;


// annotations
struct JsonProperty {
  string name;
  alias name this;
}

// retrieve metadata about how json serde should work for a field in a given type
template JsonMetadata(T, string field) {
  import std.traits;
  alias names = FieldNameTuple!T;
  alias TYPES = Fields!T;

  // the name of the
  string serialName() {
    foreach (name ; names) {
      if (name == field) {
        auto udas =  getUDAs!(__traits(getMember, T, name), JsonProperty);
        string ret = field;
        static if (udas.length != 0) {
          ret = udas[0];
        }
        return ret;
      }
    }
  } 
}

unittest {
  struct Foo {
    @JsonProperty("bar") string foo;
  }

  assert(JsonMetadata!(Foo,  "foo").serialName() == "bar");
}

template JsonCodec(T) {
  import std.traits;
  T deserialize(JSONValue json) {
    alias TYPES = Fields!T;
    alias NAMES = FieldNameTuple!T;

    auto builder = T();
    foreach (i, string name ; NAMES) {
      alias TYPE = TYPES[i];
      alias Codec = JsonCodec!TYPE;
      alias META = JsonMetadata!(T, name);

      TYPE value = Codec.deserialize(json[META.serialName()]);
      __traits(getMember, builder, name) = value;
    }
    return builder;
  }
}

unittest {
  struct Point {
    long x = 0;
    long y = 0;
  }
  struct Line {
    Point from;
    Point to;
    string label;
  }

  auto json = parseJSON(`{"from": {"x": 0, "y": 0}, "to": {"x": 2, "y": 2}, "label": "my line"}`);
  auto deser = JsonCodec!Line.deserialize(json);
  assert(deser == Line(Point(0, 0), Point(2, 2), "my line"));
}

unittest {
  struct Foo {
    @JsonProperty("baz") string bar;
  }

  auto json = parseJSON(`{"baz": "foo"}`);
  alias F = JsonCodec!Foo;
  assert(F.deserialize(json) == Foo("foo"));
}

template JsonCodec(T: long) {
  long deserialize(JSONValue value) {
    return value.integer();
  }
}

unittest {
  auto json = parseJSON(`1234`);
  auto deser = JsonCodec!(long).deserialize(json);
  assert(deser == 1234);
}

template JsonCodec(T: string) {
  string deserialize(JSONValue value) {
    return value.str();
  }
}

unittest {
  auto json = parseJSON(`"hello"`);
  auto deser = JsonCodec!(string).deserialize(json);
  assert(deser == "hello");
}

void main()
{
	writeln("Edit source/app.d to start your project.");
}

