import std.stdio;

import std.json;

// helpers
string jsonName(T)(string actualFieldName) {
  auto field = __traits(getMember, T, actualFieldName);
  writeln(field);
  return actualFieldName;
}

// UDAs
struct JsonProperty {
  string name;
}

template JsonCodec(T) {
  import std.traits;
  T deserialize(JSONValue json) {
    alias TYPES = Fields!T;
    alias NAMES = FieldNameTuple!T;

    auto builder = T.init;
    foreach (i, name ; NAMES) {
      alias TYPE = TYPES[i];
      alias Codec = JsonCodec!TYPE;
      TYPE value = Codec.deserialize(json[name]);
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
    @JsonProperty("baz")
    string bar;
  }
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

