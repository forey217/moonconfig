///|
/// Parse explicit decisions: {path, choice: base/ours/theirs/custom/delete}.
/// A custom choice requires value; JSON null remains a present value.
pub fn parse_decisions(value : Json) -> Array[Decision] raise ConfigError {
  guard value is Array(items) else {
    raise InvalidResolution("decisions must be an array")
  }
  if items.length() > 10000 {
    raise LimitExceeded("decisions exceed 10000 entries")
  }
  items.map(item => {
    guard item is Object(o) else {
      raise InvalidResolution("decision must be an object")
    }
    let path = required_string(o, "path")
    let _ = pointer_tokens(path)
    let choice = match required_string(o, "choice") {
      "base" => Base
      "ours" => Ours
      "theirs" => Theirs
      "delete" => Delete
      "custom" => {
        let value = input_document(o, "value") catch {
          _ => raise InvalidResolution("invalid custom JSON at: " + path)
        }
        validate_document(value)
        Set(value)
      }
      other => raise InvalidResolution("unknown choice: " + other)
    }
    { path, choice, }
  })
}

///|
/// The leading root test rejects any semantic change to the reviewed base.
/// Number spelling and object order are deliberately not byte-level guards.
pub fn guarded_diff(
  base : Json,
  target : Json,
) -> Array[Operation] raise ConfigError {
  let changes = diff(base, target)
  let ops : Array[Operation] = [Test("", clone_json(base))]
  // Reserve one operation for the guard, staying within apply's limit.
  if changes.length() >= 10000 {
    ops.push(Replace("", clone_json(target)))
  } else {
    for change in changes {
      ops.push(change)
    }
  }
  ops
}

///|
/// Recompute conflicts from the three documents, never trust a supplied preview.
/// Missing/duplicate/unknown decisions fail without exposing a partial result.
pub fn resolve(
  base : Json,
  ours : Json,
  theirs : Json,
  decisions : Array[Decision],
) -> ResolvedMerge raise ConfigError {
  if decisions.length() > 10000 {
    raise LimitExceeded("decisions exceed 10000 entries")
  }
  let preview = merge(base, ours, theirs)
  let conflicts : Map[String, Conflict] = Map([])
  for conflict in preview.conflicts {
    conflicts[conflict.path] = conflict
  }
  let choices : Map[String, Choice] = Map([])
  for decision in decisions {
    let _ = pointer_tokens(decision.path)
    if !conflicts.contains(decision.path) {
      raise InvalidResolution("unknown conflict path: " + decision.path)
    }
    if choices.contains(decision.path) {
      raise InvalidResolution("duplicate decision: " + decision.path)
    }
    match decision.choice {
      Set(value) => validate_document(value)
      Delete if decision.path == "" =>
        raise InvalidResolution("the document root cannot be deleted")
      _ => ()
    }
    choices[decision.path] = decision.choice
  }
  // Check completeness before editing anything.
  for conflict in preview.conflicts {
    if !choices.contains(conflict.path) {
      raise InvalidResolution("missing decision: " + conflict.path)
    }
  }
  let edits : Array[Operation] = []
  for conflict in preview.conflicts {
    let selected = match choices[conflict.path] {
      Base => conflict.base
      Ours => conflict.ours
      Theirs => conflict.theirs
      Set(custom) => Some(custom)
      Delete => None
    }
    match selected {
      Some(v) => edits.push(Add(conflict.path, v))
      None if conflict.base is Some(_) => edits.push(Remove(conflict.path))
      None => ()
    }
  }
  let value = apply(preview.value, edits)
  validate_document(value)
  let patch = guarded_diff(base, value)
  if !same(apply(base, patch), value) {
    raise InvalidResolution(
      "patch replay did not match the final configuration",
    )
  }
  { value, patch, }
}

///|
pub fn resolved_json(result : ResolvedMerge) -> Json {
  Json::object(
    Map([
      ("clean", Json::boolean(true)),
      ("verified", Json::boolean(true)),
      ("value", clone_json(result.value)),
      ("patch", patch_json(result.patch)),
    ]),
  )
}
