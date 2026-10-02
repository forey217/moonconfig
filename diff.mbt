///|
/// Produce deterministic patches. Arrays are replaced as a whole in v0.1.
pub fn diff(old : Json, new : Json) -> Array[Operation] raise ConfigError {
  validate_document(old)
  validate_document(new)
  let out : Array[Operation] = []
  diff_at(old, new, "", out)
  // Keep generated patches usable by apply's operation limit.
  if out.length() > 10000 {
    [Replace("", clone_json(new))]
  } else {
    out
  }
}

///|
fn diff_at(
  old : Json,
  new : Json,
  path : String,
  out : Array[Operation],
) -> Unit {
  if same(old, new) {
    return
  }
  match (old, new) {
    (Object(a), Object(b)) =>
      for key in keys_union(a, b) {
        let child_path = append_path(path, key)
        match (a.get(key), b.get(key)) {
          (Some(x), Some(y)) => diff_at(x, y, child_path, out)
          (Some(_), None) => out.push(Remove(child_path))
          (None, Some(y)) => out.push(Add(child_path, clone_json(y)))
          _ => ()
        }
      }
    _ => out.push(Replace(path, clone_json(new)))
  }
}
