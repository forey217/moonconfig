# Changelog

## 0.2.0 — 2026-10-02

Complete conflict review: explicit decisions, custom JSON and deletion, validated final configuration, guarded patch replay, CLI exports and browser decision controls. Added a separate MoonBit consumer module, complete CLI workflow tests, CI template and documented benchmark. Patch payload limits apply to individual values so guarded patches can carry both base and target. Full source is available on GitHub; remote CI including native tests has passed.

Published forey217/moonconfig@0.2.0 to Mooncakes. An unauthenticated standalone consumer downloaded the package, matched all 51 publication files, built successfully, passed two public API tests on JS and Wasm GC, and ran the configuration review example. See docs/registry-verification.md.

## 0.1.0 — 2026-10-02

Initial prototype: MoonBit JSON Pointer, JSON Patch, deterministic diff, three-way merge, exact decimal comparison, Node CLI, local browser workbench, conformance fixtures, project tests, documentation and CI configuration. Not yet published to Mooncakes.
