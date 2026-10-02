///|
/// Errors are recoverable: malformed input never deliberately aborts.
pub(all) suberror ConfigError {
  InvalidPointer(String)
  InvalidIndex(String)
  MissingPath(String)
  InvalidPatch(String)
  TestFailed(String)
  InvalidMove(String)
  LimitExceeded(String)
} derive(@debug.Debug)

///|
/// RFC 6902 operations. Paths are RFC 6901 JSON Pointers.
pub(all) enum Operation {
  Add(String, Json)
  Remove(String)
  Replace(String, Json)
  Move(String, String) // source, destination
  Copy(String, String) // source, destination
  Test(String, Json)
} derive(@debug.Debug, Eq)

///|
pub extend Operation with Eq::{equal, not_equal}

///|
/// Missing values are None; an explicit JSON null is Some(Null).
pub(all) struct Conflict {
  path : String
  base : Json?
  ours : Json?
  theirs : Json?
} derive(@debug.Debug, Eq)

///|
pub extend Conflict with Eq::{equal, not_equal}

///|
/// A conflicted result is a preview. Conflicting locations retain the base.
pub(all) struct MergeResult {
  value : Json
  conflicts : Array[Conflict]
} derive(@debug.Debug, Eq)

///|
pub extend MergeResult with Eq::{equal, not_equal}

///|
fn clone_json(value : Json) -> Json {
  match value {
    Array(a) => Json::array(a.map(clone_json))
    Object(o) => Json::object(o.map(fn(_, v) { clone_json(v) }))
    _ => value
  }
}

///|
/// Bound recursion and work before any operation traverses the document.
fn validate_tree(
  value : Json,
  depth : Int,
  count : Ref[Int],
) -> Unit raise ConfigError {
  if depth > 128 {
    raise LimitExceeded("document depth exceeds 128")
  }
  count.val = count.val + 1
  if count.val > 100000 {
    raise LimitExceeded("document exceeds 100000 nodes")
  }
  match value {
    Array(a) =>
      for v in a {
        validate_tree(v, depth + 1, count)
      }
    Object(o) =>
      for _, v in o {
        validate_tree(v, depth + 1, count)
      }
    Number(_, repr~) => {
      let _ = canonical_number(value, repr)
    }
    _ => ()
  }
}

///|
fn validate_document(value : Json) -> Unit raise ConfigError {
  validate_tree(value, 0, Ref(0))
}

///|
fn keys_union(a : Map[String, Json], b : Map[String, Json]) -> Array[String] {
  let keys = a.keys().to_array()
  for k, _ in b {
    if !a.contains(k) {
      keys.push(k)
    }
  }
  keys.sort_by((a, b) => a.to_array().lexical_compare(b.to_array()))
  keys
}

///|
fn append_path(path : String, key : String) -> String {
  path + "/" + key.replace_all(old="~", new="~0").replace_all(old="/", new="~1")
}

///|
pub extend ConfigError with @debug.Debug::{to_repr}

///|
pub extend Operation with @debug.Debug::{to_repr}

///|
pub extend Conflict with @debug.Debug::{to_repr}

///|
pub extend MergeResult with @debug.Debug::{to_repr}
