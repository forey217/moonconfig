///|
/// A separate MoonBit module consuming only MoonConfig's public API.
fn main {
  try {
    let base = @json.parse("{\"port\":8080,\"level\":\"info\"}")
    let ours = @json.parse("{\"port\":9090,\"level\":\"info\"}")
    let theirs = @json.parse("{\"port\":3000,\"level\":\"debug\"}")
    let preview = @config.merge(base, ours, theirs)
    println("review: conflicts=" + preview.conflicts.length().to_string())
    let reviewed = @config.resolve(base, ours, theirs, [
      { path: "/port", choice: @config.Choice::Set(@json.parse("9443")), },
    ])
    let replay = @config.apply(base, reviewed.patch)
    println("final: " + reviewed.value.stringify())
    println("replay: port=" + @config.get(replay, "/port").stringify())
    let stale = @json.parse("{\"port\":8081,\"level\":\"info\"}")
    try {
      let _ = @config.apply(stale, reviewed.patch)
      println("ERROR: stale base accepted")
    } catch {
      _ => println("stale base: rejected")
    }
  } catch {
    error => println(error.to_string())
  }
}
