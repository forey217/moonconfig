///|
fn j(text : String) -> Json raise {
  @json.parse(text)
}

///|
fn rejects(document : String, patch : String) -> Bool {
  try {
    let _ = apply(j(document), parse_patch(j(patch)))
    false
  } catch {
    _ => true
  }
}

///|
test "independent nested changes merge" {
  let r = merge(
    j("{\"server\":{\"port\":80},\"log\":\"info\"}"),
    j("{\"server\":{\"port\":8080},\"log\":\"info\"}"),
    j("{\"server\":{\"port\":80},\"log\":\"debug\"}"),
  )
  assert_eq(r.conflicts.length(), 0)
  assert_eq(r.value, j("{\"server\":{\"port\":8080},\"log\":\"debug\"}"))
}

///|
test "divergent updates retain base and report both candidates" {
  let r = merge(j("{\"port\":80}"), j("{\"port\":81}"), j("{\"port\":82}"))
  assert_eq(r.value, j("{\"port\":80}"))
  assert_eq(r.conflicts.length(), 1)
  assert_eq(r.conflicts[0].path, "/port")
  assert_eq(r.conflicts[0].ours, Some(j("81")))
  assert_eq(r.conflicts[0].theirs, Some(j("82")))
}

///|
test "delete versus null is a conflict with different presence" {
  let r = merge(j("{\"x\":1}"), j("{}"), j("{\"x\":null}"))
  assert_eq(r.conflicts[0].ours, None)
  assert_eq(r.conflicts[0].theirs, Some(Json::null()))
  let report = merge_json(r)
  assert_eq(get(report, "/conflicts/0/ours/present"), Json::boolean(false))
  assert_eq(get(report, "/conflicts/0/theirs/present"), Json::boolean(true))
}

///|
test "same deletion and same update are clean" {
  assert_eq(merge(j("{\"x\":1}"), j("{}"), j("{}")).conflicts.length(), 0)
  assert_eq(
    merge(j("{\"x\":1}"), j("{\"x\":2}"), j("{\"x\":2}")).value,
    j("{\"x\":2}"),
  )
}

///|
test "new objects with independent keys merge" {
  let r = merge(j("{}"), j("{\"new\":{\"a\":1}}"), j("{\"new\":{\"b\":2}}"))
  assert_eq(r.value, j("{\"new\":{\"a\":1,\"b\":2}}"))
  assert_eq(r.conflicts.length(), 0)
}

///|
test "delete versus nested modification conflicts at parent" {
  let r = merge(j("{\"a\":{\"x\":1}}"), j("{}"), j("{\"a\":{\"x\":2}}"))
  assert_eq(r.conflicts[0].path, "/a")
  assert_eq(r.value, j("{\"a\":{\"x\":1}}"))
}

///|
test "arrays are atomic and type replacements conflict" {
  let r = merge(j("{\"a\":[1,2]}"), j("{\"a\":[3,2]}"), j("{\"a\":[1,4]}"))
  assert_eq(r.conflicts[0].path, "/a")
  assert_eq(merge(j("0"), j("{}"), j("[]")).conflicts[0].path, "")
}

///|
test "pointer handles empty unicode slash and tilde keys" {
  let doc = j("{\"\":{\"月/兔~\":42},\"~1\":7}")
  assert_eq(get(doc, "//月~1兔~0"), j("42"))
  assert_eq(get(doc, "/~01"), j("7"))
  assert_eq(pointer_tokens("/"), [""])
}

///|
test "pointer rejects malformed escapes and fragments" {
  for path in ["a", "#/a", "/~", "/~2", "/~0~"] {
    let failed = try {
      let _ = pointer_tokens(path)
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "array insertion deletion replacement and append" {
  let doc = j("[1,2,3]")
  let ops = [
    Add("/1", j("9")),
    Remove("/0"),
    Replace("/1", j("8")),
    Add("/-", j("4")),
  ]
  assert_eq(apply(doc, ops), j("[9,8,3,4]"))
  assert_eq(doc, j("[1,2,3]"))
}

///|
test "invalid array indexes and missing parents are rejected" {
  for index in ["01", "-1", "+1", "1.0", " 0", "999999999999999999999999"] {
    assert_true(
      rejects(
        "[1,2]",
        "[{\"op\":\"add\",\"path\":\"/" + index + "\",\"value\":0}]",
      ),
    )
  }
  assert_true(rejects("[1]", "[{\"op\":\"remove\",\"path\":\"/-\"}]"))
  assert_true(
    rejects("{}", "[{\"op\":\"add\",\"path\":\"/missing/child\",\"value\":0}]"),
  )
}

///|
test "patch is atomic when a later test fails" {
  let original = j("{\"a\":{\"x\":1},\"b\":[1,2]}")
  let before = original.stringify()
  let failed = try {
    let _ = apply(original, [
      Replace("/a/x", j("2")),
      Add("/b/-", j("3")),
      Test("/a/x", j("9")),
    ])
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(original.stringify(), before)
}

///|
test "copy produces independent branches and never changes input" {
  let original = j("{\"a\":{\"x\":1}}")
  let result = apply(original, [Copy("/a", "/b"), Replace("/b/x", j("9"))])
  assert_eq(result, j("{\"a\":{\"x\":1},\"b\":{\"x\":9}}"))
  assert_eq(original, j("{\"a\":{\"x\":1}}"))
}

///|
test "move uses post-removal array indices" {
  assert_eq(
    apply(j("[\"a\",\"b\",\"c\"]"), [Move("/0", "/2")]),
    j("[\"b\",\"c\",\"a\"]"),
  )
  assert_eq(apply(j("{\"a\":1}"), [Move("/a", "/a")]), j("{\"a\":1}"))
  assert_true(
    rejects(
      "{\"a\":{\"b\":1}}", "[{\"op\":\"move\",\"from\":\"/a\",\"path\":\"/a/b/c\"}]",
    ),
  )
}

///|
test "root replacement and unsupported root deletion are explicit" {
  assert_eq(apply(j("{}"), [Add("", j("[]"))]), j("[]"))
  assert_true(rejects("{}", "[{\"op\":\"remove\",\"path\":\"\"}]"))
}

///|
test "patch parser requires correct operation fields" {
  for
    patch in [
      "{}", "[1]", "[{\"path\":\"/a\"}]", "[{\"op\":\"add\",\"path\":\"/a\"}]", "[{\"op\":\"copy\",\"path\":\"/a\",\"from\":4}]",
      "[{\"op\":\"wat\",\"path\":\"\"}]",
    ] {
    assert_true(rejects("{}", patch))
  }
}

///|
test "numeric spellings are equal but distinct huge integers are not" {
  assert_eq(diff(j("1"), j("1.00e0")).length(), 0)
  assert_eq(diff(j("-0"), j("0")).length(), 0)
  assert_eq(diff(j("1e400"), j("10e399")).length(), 0)
  assert_eq(diff(j("9007199254740992"), j("9007199254740993")).length(), 1)
  assert_true(
    rejects(
      "9007199254740992", "[{\"op\":\"test\",\"path\":\"\",\"value\":9007199254740993}]",
    ),
  )
}

///|
test "diff order is deterministic and escaped" {
  let a = diff(j("{\"z\":0,\"a/b\":1}"), j("{\"~\":3,\"z\":2}"))
  assert_eq(a, [Remove("/a~1b"), Replace("/z", j("2")), Add("/~0", j("3"))])
  assert_eq(parse_patch(patch_json(a)), a)
}

///|
test "diff apply roundtrip across a matrix of JSON values" {
  let docs = [
    "null", "true", "0", "1.5", "\"月兔\"", "[]", "[1,null]", "{}", "{\"a\":1}",
    "{\"a\":[1,2],\"b\":{\"x\":false}}", "{\"\":null,\"a/b\":2,\"~\":3}",
  ]
  for a in docs {
    for b in docs {
      let old = j(a)
      let new = j(b)
      assert_true(same(apply(old, diff(old, new)), new))
      assert_true(same(merge(old, old, new).value, new))
      assert_eq(merge(old, new, old).conflicts.length(), 0)
    }
  }
}

///|
test "public results cannot alias input nested objects" {
  let original = j("{\"a\":{\"x\":1}}")
  let result = apply(original, [])
  match result {
    Object(o) =>
      match o["a"] {
        Object(a) => a["x"] = j("9")
        _ => fail("shape")
      }
    _ => fail("shape")
  }
  assert_eq(get(original, "/a/x"), j("1"))
}

///|
test "depth and numeric exponent limits return errors" {
  let mut deep = Json::null()
  for _i = 0; _i < 130; _i = _i + 1 {
    deep = Json::array([deep])
  }
  let failed = try {
    let _ = diff(deep, Json::null())
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_true(rejects("1e1000001", "[]"))
}

///|
test "bridge reports malformed input as data" {
  let r = j(run_json("not-json"))
  assert_eq(get(r, "/ok"), Json::boolean(false))
  let bad = j(
    run_json("{\"command\":\"diff\",\"old_text\":\"0,1\",\"new_text\":\"{}\"}"),
  )
  assert_eq(get(bad, "/ok"), Json::boolean(false))
}

///|
test "large generated diffs stay applicable" {
  let fields : Map[String, Json] = Map([])
  for i = 0; i < 10001; i = i + 1 {
    fields[i.to_string()] = Json::null()
  }
  let new = Json::object(fields)
  let old = j("{}")
  let ops = diff(old, new)
  assert_eq(ops.length(), 1)
  assert_true(same(apply(old, ops), new))
}

///|
test "bridge preserves useful failing paths" {
  let response = j(
    run_json(
      "{\"command\":\"apply\",\"document\":{\"port\":80},\"patch\":[{\"op\":\"test\",\"path\":\"/port\",\"value\":81}]}",
    ),
  )
  assert_eq(get(response, "/code"), Json::string("test_failed"))
  assert_eq(get(response, "/error"), Json::string("Test failed at: /port"))
}
