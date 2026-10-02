///|
/// Merge independent object-field changes. Conflicts keep the original value.
/// Arrays are atomic values. No side silently wins a conflict.
pub fn merge(
  base : Json,
  ours : Json,
  theirs : Json,
) -> MergeResult raise ConfigError {
  validate_document(base)
  validate_document(ours)
  validate_document(theirs)
  let conflicts : Array[Conflict] = []
  let value = merge_at(Some(base), Some(ours), Some(theirs), "", conflicts)
  let merged = value.unwrap()
  validate_document(merged)
  { value: merged, conflicts, }
}

///|
fn merge_at(
  base : Json?,
  ours : Json?,
  theirs : Json?,
  path : String,
  conflicts : Array[Conflict],
) -> Json? {
  if same_slot(ours, theirs) {
    return ours.map(clone_json)
  }
  if same_slot(ours, base) {
    return theirs.map(clone_json)
  }
  if same_slot(theirs, base) {
    return ours.map(clone_json)
  }
  let base_object : Map[String, Json]? = match base {
    Some(Object(o)) => Some(o)
    None => Some(Map([]))
    _ => None
  }
  match (base_object, ours, theirs) {
    (Some(b), Some(Object(o)), Some(Object(t))) => {
      let keys = keys_union(b, o)
      for k, _ in t {
        if !keys.contains(k) {
          keys.push(k)
        }
      }
      keys.sort_by((a, b) => a.to_array().lexical_compare(b.to_array()))
      let result : Map[String, Json] = Map([])
      for k in keys {
        match
          merge_at(
            b.get(k),
            o.get(k),
            t.get(k),
            append_path(path, k),
            conflicts,
          ) {
          Some(v) => result[k] = v
          None => ()
        }
      }
      Some(Json::object(result))
    }
    _ => {
      conflicts.push({
        path,
        base: base.map(clone_json),
        ours: ours.map(clone_json),
        theirs: theirs.map(clone_json),
      })
      base.map(clone_json)
    }
  }
}

///|
/// Stable report distinguishes deleted fields from explicit null values.
pub fn merge_json(result : MergeResult) -> Json {
  fn slot(value : Json?) -> Json {
    let o : Map[String, Json] = Map([])
    o["present"] = Json::boolean(value is Some(_))
    match value {
      Some(v) => o["value"] = clone_json(v)
      None => ()
    }
    Json::object(o)
  }
  let o : Map[String, Json] = Map([])
  o["clean"] = Json::boolean(result.conflicts.is_empty())
  o["value"] = clone_json(result.value)
  o["conflicts"] = Json::array(
    result.conflicts.map(fn(c) {
      Json::object(
        Map([
          ("path", Json::string(c.path)),
          ("base", slot(c.base)),
          ("ours", slot(c.ours)),
          ("theirs", slot(c.theirs)),
        ]),
      )
    }),
  )
  Json::object(o)
}
