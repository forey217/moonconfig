///|
/// JSON string boundary shared by the Node CLI and browser demo.
/// Request: {command, old, new} / {command, document, patch} /
/// {command, base, ours, theirs} / {command, document, path}.
pub fn run_json(request_text : String) -> String {
  let response : Map[String, Json] = Map([])
  try {
    if request_text.length() > 4000000 {
      raise LimitExceeded("request exceeds 4000000 code units")
    }
    let request = @json.parse(request_text)
    guard request is Object(o) else {
      raise InvalidPatch("request must be an object")
    }
    let result = match required_string(o, "command") {
      "diff" =>
        patch_json(diff(required_field(o, "old"), required_field(o, "new")))
      "apply" =>
        apply(
          required_field(o, "document"),
          parse_patch(required_field(o, "patch")),
        )
      "merge" =>
        merge_json(
          merge(
            required_field(o, "base"),
            required_field(o, "ours"),
            required_field(o, "theirs"),
          ),
        )
      "get" => get(required_field(o, "document"), required_string(o, "path"))
      other => raise InvalidPatch("unknown command: " + other)
    }
    response["ok"] = Json::boolean(true)
    response["result"] = result
  } catch {
    error => {
      let (code, message) = explain_error(error)
      response["ok"] = Json::boolean(false)
      response["code"] = Json::string(code)
      response["error"] = Json::string(message)
    }
  }
  Json::object(response).stringify()
}

///|
fn explain_error(error : Error) -> (String, String) {
  match error {
    ConfigError::InvalidPointer(path) =>
      ("invalid_pointer", "Invalid JSON Pointer: " + path)
    ConfigError::InvalidIndex(index) =>
      ("invalid_index", "Invalid or out-of-range array index: " + index)
    ConfigError::MissingPath(path) =>
      ("missing_path", "Path does not exist: " + path)
    ConfigError::InvalidPatch(message) => ("invalid_patch", message)
    ConfigError::TestFailed(path) => ("test_failed", "Test failed at: " + path)
    ConfigError::InvalidMove(message) => ("invalid_move", message)
    ConfigError::LimitExceeded(message) => ("limit_exceeded", message)
    _ => ("invalid_json", "Invalid JSON input: " + error.to_string())
  }
}

///|
/// Extract without rounding large numbers in JavaScript.
pub fn result_json(response : String) -> String {
  try {
    guard @json.parse(response) is Object(o) else { return response }
    required_field(o, "result").stringify(indent=2)
  } catch {
    _ => response
  }
}
