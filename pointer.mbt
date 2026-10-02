///|
/// Parse a plain JSON Pointer. URI fragments are deliberately not accepted.
pub fn pointer_tokens(path : String) -> Array[String] raise ConfigError {
  if path == "" {
    return []
  }
  guard path.strip_prefix("/") is Some(tail) else { raise InvalidPointer(path) }
  let parts = tail.split("/").to_array()
  if parts.length() > 128 {
    raise LimitExceeded("pointer exceeds 128 segments")
  }
  parts.map(part => {
    let chars = part.to_array()
    let out : Array[Char] = []
    let mut i = 0
    while i < chars.length() {
      if chars[i] == '~' {
        if i + 1 >= chars.length() {
          raise InvalidPointer(path)
        }
        match chars[i + 1] {
          '0' => out.push('~')
          '1' => out.push('/')
          _ => raise InvalidPointer(path)
        }
        i = i + 2
      } else {
        out.push(chars[i])
        i = i + 1
      }
    }
    String::from_array(out)
  })
}

///|
/// RFC array indices forbid signs, whitespace and leading zeroes.
fn array_index(
  token : String,
  length : Int,
  insertion : Bool,
) -> Int raise ConfigError {
  if token == "-" && insertion {
    return length
  }
  let chars = token.to_array()
  if chars.is_empty() || (chars.length() > 1 && chars[0] == '0') {
    raise InvalidIndex(token)
  }
  let mut n = 0
  for c in chars {
    if c < '0' || c > '9' {
      raise InvalidIndex(token)
    }
    let digit = c.to_int() - '0'.to_int()
    if n > length / 10 || (n == length / 10 && digit > length % 10) {
      raise InvalidIndex(token)
    }
    n = n * 10 + digit
  }
  if n >= length && !insertion {
    raise InvalidIndex(token)
  }
  n
}

///|
fn get_at(
  value : Json,
  tokens : Array[String],
  offset : Int,
  path : String,
) -> Json raise ConfigError {
  if offset == tokens.length() {
    return value
  }
  let token = tokens[offset]
  match value {
    Object(o) => {
      guard o.get(token) is Some(child) else { raise MissingPath(path) }
      get_at(child, tokens, offset + 1, path)
    }
    Array(a) =>
      get_at(a[array_index(token, a.length(), false)], tokens, offset + 1, path)
    _ => raise MissingPath(path)
  }
}

///|
/// Return an independent value, rather than an alias into the caller's tree.
pub fn get(document : Json, path : String) -> Json raise ConfigError {
  validate_document(document)
  clone_json(get_at(document, pointer_tokens(path), 0, path))
}

///|
priv enum EditMode {
  Insert
  Delete
  Update
}

///|
/// Copy every edited ancestor; untouched input is never mutated.
fn edit_at(
  value : Json,
  tokens : Array[String],
  offset : Int,
  path : String,
  mode : EditMode,
  replacement : Json,
) -> Json raise ConfigError {
  if offset == tokens.length() {
    // This API always returns a JSON document; root deletion has no such result.
    if mode is Delete {
      raise InvalidPatch("root deletion is not supported")
    }
    return clone_json(replacement)
  }
  let token = tokens[offset]
  let last = offset + 1 == tokens.length()
  match value {
    Object(o) => {
      let out = o.copy()
      if last {
        match mode {
          Insert => out[token] = clone_json(replacement)
          Delete => {
            if !o.contains(token) {
              raise MissingPath(path)
            }
            out.remove(token)
          }
          Update => {
            if !o.contains(token) {
              raise MissingPath(path)
            }
            out[token] = clone_json(replacement)
          }
        }
      } else {
        guard o.get(token) is Some(child) else { raise MissingPath(path) }
        out[token] = edit_at(child, tokens, offset + 1, path, mode, replacement)
      }
      Json::object(out)
    }
    Array(a) => {
      let out = a.copy()
      let index = array_index(token, a.length(), last && mode is Insert)
      if last {
        match mode {
          Insert => out.insert(index, clone_json(replacement))
          Delete => {
            let _ = out.remove(index)
          }
          Update => out[index] = clone_json(replacement)
        }
      } else {
        out[index] = edit_at(
          a[index],
          tokens,
          offset + 1,
          path,
          mode,
          replacement,
        )
      }
      Json::array(out)
    }
    _ => raise MissingPath(path)
  }
}
