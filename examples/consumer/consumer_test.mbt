///|
test "public API closes the configuration review loop" {
  let b = @json.parse("{\"port\":80,\"id\":9007199254740992}")
  let o = @json.parse("{\"port\":81,\"id\":9007199254740993}")
  let t = @json.parse("{\"port\":82,\"id\":9007199254740992}")
  let r = @config.resolve(b, o, t, [
    { path: "/port", choice: @config.Choice::Theirs, },
  ])
  let replay = @config.apply(
    b,
    @config.parse_patch(@config.patch_json(r.patch)),
  )
  assert_eq(@config.get(replay, "/port").stringify(), "82")
  assert_eq(@config.get(replay, "/id").stringify(), "9007199254740993")
}

///|
test "public API rejects unresolved decisions and stale configuration" {
  let b = @json.parse("0")
  let o = @json.parse("1")
  let t = @json.parse("2")
  let incomplete = try {
    let _ = @config.resolve(b, o, t, [])
    false
  } catch {
    _ => true
  }
  assert_true(incomplete)
  let r = @config.resolve(b, o, t, [{ path: "", choice: @config.Choice::Ours, }])
  let blocked = try {
    let _ = @config.apply(@json.parse("9"), r.patch)
    false
  } catch {
    _ => true
  }
  assert_true(blocked)
}
