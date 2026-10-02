# MoonConfig

A MoonBit JSON configuration review library: three-way merge, explicit conflict decisions, final configuration and base-guarded JSON Patch replay.

Version 0.2 closes the review loop. Independent object changes merge; conflicts require exactly one choice (base/ours/theirs/delete/custom). Missing fields differ from null. The final patch starts with a whole-base test, and the core verifies that replay produces the final configuration. Stale configurations are rejected.

## Run

Requires the official MoonBit toolchain and Node.js 20+. No npm dependencies.

```sh
git clone https://github.com/forey217/moonconfig.git
cd moonconfig
npm run build
npm run demo
```

Open http://127.0.0.1:4173. Use the conflict scenario, choose each result, confirm, then export the final value or guarded patch. Inputs stay in the browser. Changing inputs clears decisions.

The full source is available on GitHub, and remote CI has passed. Mooncakes publication and contest registration are not complete. See the [remote verification record](docs/ci-verification.md).

## CLI

```sh
node scripts/moonconfig.mjs merge BASE.json OURS.json THEIRS.json
node scripts/moonconfig.mjs resolve BASE.json OURS.json THEIRS.json DECISIONS.json
node scripts/moonconfig.mjs resolve BASE.json OURS.json THEIRS.json DECISIONS.json --output value
node scripts/moonconfig.mjs resolve BASE.json OURS.json THEIRS.json DECISIONS.json --output patch
node scripts/moonconfig.mjs diff OLD.json NEW.json
node scripts/moonconfig.mjs apply DOCUMENT.json PATCH.json
node scripts/moonconfig.mjs get DOCUMENT.json /path
```

Decisions: `[{"path":"/port","choice":"custom","value":9443}]`. Choices are base, ours, theirs, delete, custom. Missing/duplicate/unknown choices and invalid values fail. Empty decisions are valid for clean merges.

Exit codes: 0 success, 1 input/I/O/operation/decision error, 2 unresolved merge conflicts. Results go to stdout, errors to stderr. Files are never overwritten. Use UTF-8 for output; a UTF-8 BOM is accepted.

## Independent reuse

The core uses only the MoonBit standard library. Public APIs include merge, resolve, guarded_diff, diff and apply. See pkg.generated.mbti and the Chinese README.

examples/consumer has its own module manifest and uses only public APIs. moon.work resolves the versioned dependency to local source:

```sh
cd examples/consumer
moon run cmd/main --target js
moon test --package forey217/config-gate-example --target js --deny-warn
```

This demonstrates cross-module consumption, not registry installation or external adoption. Existing structural JSON diff/patch libraries include tiye/recollect. This project's focus is configuration three-way review with explicit decisions and guarded replay; it does not claim to be the first JSON diff library.

## Validation and boundaries

150 MoonBit workspace tests: 148 library tests (108 upstream cases and 40 project tests) plus 2 consumer black-box tests. Three Node tests exercise real CLI processes and the complete review workflow. JS and Wasm GC are validated locally. Linux GitHub Actions has passed JS, Wasm GC and native tests, the build, the independent consumer and the Node integration tests. See the [remote verification record](docs/ci-verification.md). A native C compiler remains unavailable on the local Windows machine.

```sh
npm run test
moon test --target wasm-gc --deny-warn
node scripts/benchmark.mjs
```

Arrays are whole values. Root removal is unsupported. Base guards compare semantics, not bytes: object order and equivalent decimal spellings may change. No schema validation, minimal-patch or full RFC-certification claim. Returned JSON containers are mutable; revalidate after modifying them.

Documents and operation values: 128 levels, 100000 nodes; patches: 10000 operations; decisions: 10000; pointers: 128 segments; bridge: 4000000 UTF-16 units; decimal exponent: ±1000000. Browser interaction is limited to 200 conflicts. Larger diffs fall back to root replacement while reserving a guard operation. Duplicate keys use the parser's last-value rule. These limits do not provide strict hostile-input resource isolation.

See [review workflow](docs/workflow.md), [design](docs/design.md), [proposal](docs/proposal.md), [benchmark](docs/benchmark.md), and [review progress](docs/review-plan.md). Code is MIT; imported fixtures and generated conformance tests are Apache-2.0, documented in THIRD_PARTY_NOTICES.md. AI assisted development; the participant must understand and review the work.
