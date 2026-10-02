///|
fn required_field(
  o : Map[String, Json],
  field : String,
) -> Json raise ConfigError {
  guard o.get(field) is Some(value) else {
    raise InvalidPatch("missing " + field)
  }
  value
}

///|
fn required_string(
  o : Map[String, Json],
  field : String,
) -> String raise ConfigError {
  guard required_field(o, field) is String(value) else {
    raise InvalidPatch(field + " must be a string")
  }
  value
}

///|
/// Unknown operation members are ignored, as required by RFC 6902.
pub fn parse_patch(value : Json) -> Array[Operation] raise ConfigError {
  validate_document(value)
  guard value is Array(ops) else {
    raise InvalidPatch("patch must be an array")
  }
  if ops.length() > 10000 {
    raise LimitExceeded("patch exceeds 10000 operations")
  }
  ops.map(op => {
    guard op is Object(o) else {
      raise InvalidPatch("operation must be an object")
    }
    let path = required_string(o, "path")
    let _ = pointer_tokens(path)
    match required_string(o, "op") {
      "add" => Add(path, required_field(o, "value"))
      "remove" => Remove(path)
      "replace" => Replace(path, required_field(o, "value"))
      "test" => Test(path, required_field(o, "value"))
      "move" => {
        let source = required_string(o, "from")
        let _ = pointer_tokens(source)
        Move(source, path)
      }
      "copy" => {
        let source = required_string(o, "from")
        let _ = pointer_tokens(source)
        Copy(source, path)
      }
      other => raise InvalidPatch("unknown operation: " + other)
    }
  })
}

///|
pub fn patch_json(ops : Array[Operation]) -> Json {
  Json::array(
    ops.map(op => {
      let o : Map[String, Json] = Map([])
      match op {
        Add(path, value) | Replace(path, value) | Test(path, value) => {
          o["op"] = Json::string(
            match op {
              Add(_, _) => "add"
              Replace(_, _) => "replace"
              _ => "test"
            },
          )
          o["path"] = Json::string(path)
          o["value"] = clone_json(value)
        }
        Remove(path) => {
          o["op"] = Json::string("remove")
          o["path"] = Json::string(path)
        }
        Move(source, path) | Copy(source, path) => {
          o["op"] = Json::string(if op is Move(_, _) { "move" } else { "copy" })
          o["path"] = Json::string(path)
          o["from"] = Json::string(source)
        }
      }
      Json::object(o)
    }),
  )
}

///|
/// Apply in order. On any error, the caller's document and patch stay unchanged.
/// Root removal is rejected because this API must return a JSON document.
pub fn apply(document : Json, ops : Array[Operation]) -> Json raise ConfigError {
  validate_document(document)
  if ops.length() > 10000 {
    raise LimitExceeded("patch exceeds 10000 operations")
  }
  let mut current = clone_json(document)
  for op in ops {
    current = match op {
      Add(path, value) | Replace(path, value) => {
        validate_document(value)
        edit_at(
          current,
          pointer_tokens(path),
          0,
          path,
          if op is Add(_, _) {
            Insert
          } else {
            Update
          },
          value,
        )
      }
      Remove(path) =>
        edit_at(current, pointer_tokens(path), 0, path, Delete, Json::null())
      Test(path, value) => {
        validate_document(value)
        if !same(get_at(current, pointer_tokens(path), 0, path), value) {
          raise TestFailed(path)
        }
        current
      }
      Copy(source, path) => {
        let value = get_at(current, pointer_tokens(source), 0, source)
        edit_at(current, pointer_tokens(path), 0, path, Insert, value)
      }
      Move(source, path) => {
        let from = pointer_tokens(source)
        let to = pointer_tokens(path)
        let value = get_at(current, from, 0, source)
        if from == to {
          current
        } else {
          if to.length() > from.length() &&
            to.exact_view(end=from.length()) == from.exact_view() {
            raise InvalidMove("destination is inside source")
          }
          let removed = edit_at(current, from, 0, source, Delete, Json::null())
          edit_at(removed, to, 0, path, Insert, value)
        }
      }
    }
    validate_document(current)
  }
  current
}
