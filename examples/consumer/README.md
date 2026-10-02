# Independent MoonBit consumer

This directory is a separate MoonBit module, `forey217/config-gate-example`, with a versioned dependency on `forey217/moonconfig`. It uses only public interfaces; it is an integration example, not evidence of external adoption.

The repository's moon.work resolves the dependency from local source, following the official workspace mechanism. No unpublished registry package is required.

From this directory:

```sh
moon run cmd/main --target js
moon test --package forey217/config-gate-example --target js --deny-warn
```

Expected output:

```text
review: conflicts=1
final: {"level":"debug","port":9443}
replay: port=9443
stale base: rejected
```

Object key order is not part of the guarantee. Tests validate independent changes, exact integers, missing decisions, guarded replay and rejection of a stale base.

To validate registry installation after publication: copy this module outside the repository/workspace, run `moon update`, and repeat the commands. Registry installation has not yet been verified; the current package is not published.
