///|
fn invalid_resolution(decisions : Array[Decision]) -> Bool {
  try {
    let _ = resolve(j("{\"x\":1}"), j("{\"x\":2}"), j("{\"x\":3}"), decisions)
    false
  } catch {
    _ => true
  }
}

///|
test "resolution preserves independent changes and replay guard" {
  let base = j("{\"port\":80,\"level\":\"info\"}")
  let r = resolve(
    base,
    j("{\"port\":81,\"level\":\"info\"}"),
    j("{\"port\":82,\"level\":\"debug\"}"),
    [{ path: "/port", choice: Ours, }],
  )
  assert_eq(r.value, j("{\"port\":81,\"level\":\"debug\"}"))
  assert_true(r.patch[0] is Test("", _))
  assert_true(same(apply(base, parse_patch(patch_json(r.patch))), r.value))
  assert_eq(base, j("{\"port\":80,\"level\":\"info\"}"))
}

///|
test "all decisions require known unique conflict paths" {
  assert_true(invalid_resolution([]))
  assert_true(invalid_resolution([{ path: "/unknown", choice: Ours, }]))
  assert_true(
    invalid_resolution([
      { path: "/x", choice: Ours, },
      { path: "/x", choice: Theirs, },
    ]),
  )
}

///|
test "base theirs and custom are explicit choices" {
  for (choice, expected) in [(Base, "1"), (Theirs, "3"), (Set(j("99")), "99")] {
    let r = resolve(j("1"), j("2"), j("3"), [{ path: "", choice, }])
    assert_eq(r.value, j(expected))
    assert_true(same(apply(j("1"), r.patch), r.value))
  }
}

///|
test "delete and custom null have different presence" {
  let b = j("{\"x\":1}")
  let o = j("{\"x\":2}")
  let t = j("{\"x\":3}")
  assert_eq(resolve(b, o, t, [{ path: "/x", choice: Delete, }]).value, j("{}"))
  assert_eq(
    resolve(b, o, t, [{ path: "/x", choice: Set(Json::null()), }]).value,
    j("{\"x\":null}"),
  )
}

///|
test "selecting a deleted side removes a conflicting field" {
  assert_eq(
    resolve(j("{\"x\":1}"), j("{}"), j("{\"x\":2}"), [
      { path: "/x", choice: Ours, },
    ]).value,
    j("{}"),
  )
}

///|
test "new conflicting fields can retain absence or select a candidate" {
  let b = j("{}")
  let o = j("{\"x\":1}")
  let t = j("{\"x\":2}")
  for choice in [Base, Delete] {
    assert_eq(resolve(b, o, t, [{ path: "/x", choice, }]).value, b)
  }
  assert_eq(resolve(b, o, t, [{ path: "/x", choice: Theirs, }]).value, t)
}

///|
test "new nested conflicts and escaped paths resolve" {
  let r = resolve(
    j("{}"),
    j("{\"a/b\":{\"~\":1}}"),
    j("{\"a/b\":{\"~\":2,\"keep\":3}}"),
    [{ path: "/a~1b/~0", choice: Ours, }],
  )
  assert_eq(r.value, j("{\"a/b\":{\"~\":1,\"keep\":3}}"))
}

///|
test "multiple decisions are independent of supplied order" {
  let b = j("{\"a\":0,\"b\":0}")
  let o = j("{\"a\":1,\"b\":1}")
  let t = j("{\"a\":2,\"b\":2}")
  let forward = [{ path: "/a", choice: Ours, }, { path: "/b", choice: Theirs, }]
  let reverse = [{ path: "/b", choice: Theirs, }, { path: "/a", choice: Ours, }]
  assert_eq(resolve(b, o, t, forward).patch, resolve(b, o, t, reverse).patch)
  assert_eq(resolve(b, o, t, forward).value, j("{\"a\":1,\"b\":2}"))
}

///|
test "stale base rejects before any change" {
  let r = resolve(j("{\"x\":1}"), j("{\"x\":2}"), j("{\"x\":3}"), [
    { path: "/x", choice: Ours, },
  ])
  let stale = j("{\"x\":1,\"extra\":true}")
  let failed = try {
    let _ = apply(stale, r.patch)
    false
  } catch {
    ConfigError::TestFailed(path) => path == ""
    _ => false
  }
  assert_true(failed)
  assert_eq(stale, j("{\"x\":1,\"extra\":true}"))
}

///|
test "base guard uses semantic numeric equality" {
  let patch = guarded_diff(j("{\"a\":1,\"b\":true}"), j("{\"a\":2,\"b\":true}"))
  assert_eq(
    apply(j("{\"b\":true,\"a\":1.00}"), patch),
    j("{\"a\":2,\"b\":true}"),
  )
}

///|
test "root deletion fails and arrays resolve atomically" {
  let failed = try {
    let _ = resolve(j("0"), j("1"), j("2"), [{ path: "", choice: Delete, }])
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let r = resolve(j("[1,2]"), j("[3,2]"), j("[1,4]"), [
    { path: "", choice: Theirs, },
  ])
  assert_eq(r.value, j("[1,4]"))
}

///|
test "decision parser rejects malformed choices and accepts exact numbers" {
  for
    text in [
      "{}", "[1]", "[{\"path\":\"/x\",\"choice\":\"custom\"}]", "[{\"path\":\"/x\",\"choice\":\"auto\"}]",
    ] {
    let failed = try {
      let _ = parse_decisions(j(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  let r = resolve(
    j("{\"x\":0}"),
    j("{\"x\":1}"),
    j("{\"x\":2}"),
    parse_decisions(
      j("[{\"path\":\"/x\",\"choice\":\"custom\",\"value\":9007199254740993}]"),
    ),
  )
  assert_eq(get(r.value, "/x").stringify(), "9007199254740993")
}

///|
test "clean merges accept no decisions and reject invented conflicts" {
  let b = j("{\"x\":0}")
  let o = j("{\"x\":1}")
  assert_eq(resolve(b, o, b, []).value, o)
  let failed = try {
    let _ = resolve(b, o, b, [{ path: "/x", choice: Ours, }])
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "custom selections and review output do not alias input" {
  let custom = j("{\"nested\":1}")
  let r = resolve(j("0"), j("1"), j("2"), [{ path: "", choice: Set(custom), }])
  match custom {
    Object(o) => o["nested"] = j("9")
    _ => fail("shape")
  }
  assert_eq(get(r.value, "/nested"), j("1"))
  assert_eq(get(apply(j("0"), r.patch), "/nested"), j("1"))
}

///|
test "guard reserves a patch operation at the limit" {
  let fields : Map[String, Json] = Map([])
  for i = 0; i < 10000; i = i + 1 {
    fields[i.to_string()] = Json::null()
  }
  let target = Json::object(fields)
  let patch = guarded_diff(j("{}"), target)
  assert_eq(patch.length(), 2)
  assert_true(same(apply(j("{}"), parse_patch(patch_json(patch))), target))
}

///|
test "guarded patch payload limits apply per document" {
  let large = Json::array(Array::make(60000, Json::null()))
  let changed = Array::make(60000, Json::null())
  changed[0] = Json::boolean(true)
  let target = Json::array(changed)
  let patch = guarded_diff(large, target)
  assert_true(same(apply(large, parse_patch(patch_json(patch))), target))
}
