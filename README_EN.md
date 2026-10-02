# MoonConfig

A MoonBit library for structured JSON diffs, atomic JSON Patch application, and three-way configuration merges. This is a v0.1 prototype prepared for the 2026 MoonBit hackathon; registration and acceptance are not yet complete.

Independent object-field edits merge automatically. Different edits at the same location produce explicit conflicts and retain the base value in the review preview. Missing fields and JSON null are distinct. Arrays are treated as whole values.

## Run

Requires the official MoonBit toolchain and Node.js 20+. No npm dependencies or npm install step.

```sh
git clone https://github.com/forey217/moonconfig.git
cd moonconfig
npm run build
node scripts/moonconfig.mjs merge examples/base.json examples/ours.json examples/theirs.json
npm run demo
```

Visit http://127.0.0.1:4173 for the browser workbench. The browser processes configuration locally. The server only serves static demo files.

## CLI

```sh
node scripts/moonconfig.mjs diff OLD.json NEW.json
node scripts/moonconfig.mjs apply DOCUMENT.json PATCH.json
node scripts/moonconfig.mjs merge BASE.json OURS.json THEIRS.json
node scripts/moonconfig.mjs get DOCUMENT.json /path
```

Results go to stdout and errors to stderr. Exit codes: 0 success, 1 input/I/O/operation error, 2 unresolved merge conflicts. Input files are never overwritten. Use UTF-8 for saved output; the CLI accepts a UTF-8 BOM.

## Core behavior

- Deterministic object-field diffs generating JSON Patch; arrays use replace.
- Strict JSON Pointer escaping and array indices.
- add, remove, replace, move, copy, test; errors leave the input unchanged.
- Three-way merges with explicit base/ours/theirs candidates and presence markers.
- Decimal comparison without rounding through JavaScript Number, including large integers.
- Deep copies isolate results from mutable input containers.

The core uses MoonBit's standard library only. See pkg.generated.mbti for public interfaces and the Chinese README for usage examples. This package is not yet published to Mooncakes.

## Limits

A merge with `clean:false` is a review preview requiring resolution. Root remove is unsupported because the API always returns a JSON document. There is no minimal-patch or full RFC-certification claim. Diffs exceeding 10000 operations fall back to one root replace.

Documents: 128 levels, 100000 nodes; patches: 10000 operations; pointers: 128 segments; string bridge: 4000000 UTF-16 code units; decimal exponent: ±1000000. Duplicate keys use the parser's last-value rule. Whitespace and comments are not preserved. Precision already lost before entering the library cannot be recovered. These limits do not provide strict hostile-input resource isolation.

## Verify

```sh
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
npm run build
node --test tests/cli.test.mjs
```

132 MoonBit tests include 108 enabled upstream JSON Patch cases and 24 project tests, including a 121-pair roundtrip matrix. Node integration tests exercise the actual CLI. JS and Wasm GC are tested locally. Windows native testing requires an unavailable C compiler; Linux native testing is configured in CI and still needs remote confirmation.

See [design](docs/design.md), [proposal draft](docs/proposal.md), and [development notes](docs/development.md). Code is MIT. Upstream test fixtures and generated conformance tests are Apache-2.0; see [third-party notices](THIRD_PARTY_NOTICES.md). AI assisted development; the participant must understand, review, and maintain the submitted work.
