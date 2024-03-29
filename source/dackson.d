module dackson;

import std.stdio;
import std.json;
import std.outbuffer;

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
    assert(0);
  }
}

unittest {
  struct Foo {
    @JsonProperty("bar") string foo;
  }

  assert(JsonMetadata!(Foo,  "foo").serialName() == "bar");
}

template canZeroConstruct(T) {
  static if (__traits(compiles, T())) {
    enum bool canZeroConstruct = true;
  } else {
    enum bool canZeroConstruct = false;
  }
}

unittest {
  struct Foo {
    int bar;
    int andOne() { return bar + 1; }
  }

  class Bar {
    this(int param) {}
  }
  assert(canZeroConstruct!Bar == false);
}


template JsonCodec(T) if(canZeroConstruct!T) {
  import std.traits;
  T deserialize(JSONValue json) {
    alias TYPES = Fields!T;
    alias NAMES = FieldNameTuple!T;

    auto builder = T();
    foreach (i, string name ; NAMES) {
      alias TYPE = TYPES[i];
      alias Codec = JsonCodec!TYPE;
      alias META = JsonMetadata!(T, name);

      if (META.serialName() in json) {
        TYPE value = cast(TYPE)Codec.deserialize(json[META.serialName()]);
        __traits(getMember, builder, name) = value;
      }
    }
    return builder;
  }

  void serialize(T source, JBuffer writer) {
    writer.startObject();
    alias TYPES = Fields!T;
    alias NAMES = FieldNameTuple!T;

    bool leadComma = false;
    foreach (i, string name ; NAMES) {
      alias TYPE = TYPES[i];
      alias Codec = JsonCodec!TYPE;
      alias META = JsonMetadata!(T, name);

      if (leadComma) {
        writer.comma();
      }
      leadComma = true;

      writer.str(META.serialName());
      writer.colon();
      Codec.serialize(__traits(getMember, source, name), writer);
    }

    writer.endObject();
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
  struct User {
    @JsonProperty("user_name") string userName;
  }

  auto json = parseJSON(`{"user_name": "Lee"}`);
  alias codec = JsonCodec!User;
  assert(codec.deserialize(json) == User("Lee"));
}


template JsonCodec(T : T[]) {
  T[] deserialize(JSONValue value) {
    alias CODEC = JsonCodec!T;

    T[] ts; // TODO: pre-size this
    foreach (i, val ; value.array()) {
      ts ~= CODEC.deserialize(val);
    }
    return ts;
  }

  void serialize(T[] source, JBuffer buffer) {
    alias CODEC = JsonCodec!T;
    buffer.startArray();
    bool leadSlash = false;
    foreach (i, s ; source) {
      if (leadSlash) {
        buffer.comma();
      }
      leadSlash = true;
      CODEC.serialize(s, buffer);
    }
    buffer.endArray();
  }
}

unittest {
  auto json = `[1,2,3,4]`;
  long[] longs = json.decodeJson!(long[]);
  assert(longs == [1,2,3,4]);
  auto encoded = longs.encodeJson;
  assert(json == encoded);
}

template JsonCodec(T: JSONValue) {
  JSONValue deserialize(JSONValue v) {
    return v;
  }

  void serialize(JSONValue value, JBuffer buffer) {
    buffer.json(value);
  }
}

unittest {
  struct User {
    JSONValue data; 
  }
  string json = `{"data": {"foo": 1, "bar": [1,2,3]}}`;
  auto decoded = json.decodeJson!User;
  assert(decoded == User(JSONValue(["foo": JSONValue(1), "bar": JSONValue([1,2,3])])));
  
  assert(decoded == decoded.encodeJson().decodeJson!User);
}

template JsonCodec(T: long) {
  long deserialize(JSONValue value) {
    return value.integer();
  }

  void serialize(long source, JBuffer buffer) {
    buffer.numeric(source);
  }
}

template JsonCodec(T: float) {
  float deserialize(JSONValue value) {
    return value.floating();
  }

  void serialize(float source, JBuffer buffer) {
    buffer.floating(source);
  }
}

template JsonCodec(T: string) {
  string deserialize(JSONValue value) {
    return value.str();
  }

  void serialize(string source, JBuffer buffer) {
    buffer.str(source);
  }
}

template JsonCodec(T: bool) {
  bool deserialize(JSONValue value) {
    switch(value.type()) {
      case JSONType.true_:
       return true;
      case JSONType.false_:
       return false;
      default:
       throw new Error("value is not a boolean");
    }
  }

  void serialize(bool source, JBuffer buffer) {
    buffer.boolean(source);
  }
}

private struct JBuffer {
  private OutBuffer buffer;
  this(OutBuffer buffer) { this.buffer = buffer; }

  JBuffer startObject() { buffer.write("{"); return this; }
  JBuffer endObject() { buffer.write("}"); return this; }
  JBuffer startArray() { buffer.write("["); return this; }
  JBuffer endArray() { buffer.write("]"); return this; }
  JBuffer colon() { buffer.write(":"); return this; }
  JBuffer comma() { buffer.write(","); return this; }
  JBuffer numeric(long l) { buffer.writef("%d", l); return this; }
  JBuffer floating(float f) { buffer.writef("%f", f); return this; }
  JBuffer str(string st) { buffer.writef(`"%s"`, escape(st)); return this; }
  JBuffer boolean(bool b) { b ? buffer.write("true") : buffer.write("false"); return this; }
  JBuffer json(JSONValue value) { buffer.write(value.toString()); return this; }

  private string escape(string str) {
    // TODO(lavital): really escape
    return str;
  }
}


/**
  * Decode a JSON string into some datatype.
  */
T decodeJson(T)(string json) {
  alias CODEC = JsonCodec!T;
  JSONValue value = parseJSON(json);
  return CODEC.deserialize(value);
}

///
unittest {
  struct User {
    @JsonProperty("user_name") string userName;
  }

  string json = `{"user_name": "John Smith"}`;
  auto decoded = json.decodeJson!User;
  assert(decoded == User("John Smith"));

}


/**
  * Encode an object into a JSON string.
  */
string encodeJson(T)(T source) {
  alias Codec = JsonCodec!T;
  auto buffer = JBuffer(new OutBuffer());
  Codec.serialize(source, buffer);
  return buffer.buffer.toString();
}

///
unittest {
  string json = `1234`;
  auto deser = decodeJson!(long)(json);
  assert(deser == 1234);
  string serialized = encodeJson(deser);
  assert(serialized == json);

  json = `"hello"`;
  string deserString = `"hello"`.decodeJson!string;
  assert(deserString == "hello");
  serialized = encodeJson(deserString);
  assert(json == serialized);

  json = `true`;
  auto deserBool = json.decodeJson!bool;
  assert(deserBool == true);
  serialized = encodeJson(deserBool);
  assert(serialized == json);

  struct OneField {
    @JsonProperty("foo") string bar;
  }
  json = `{"foo":"hello"}`;
  auto deserOneField = json.decodeJson!OneField;
  assert(deserOneField == OneField("hello"));
  serialized = encodeJson(deserOneField);
  assert(serialized == json);

  json = `{}`;
  auto emptyOneField = json.decodeJson!OneField;
  assert(emptyOneField == OneField(null));
}