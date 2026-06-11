## Why

`result_builder.lua` currently mixes two concerns: orchestrating test result flow AND knowing how to read a JUnit XML report. The JUnit-reading logic (`parse(filepath) → walk testsuite.testcase → build JunitResult objects`) is private to `load_all_testcases`, and the only seam for testing it is `read_file` — the entire JUnit walk is untested. A malformed, empty, or single-testcase JUnit file today can only be exercised by feeding strings into a hand-rolled `read_file` stub; we can't swap the reader for a fake that returns pre-parsed trees.

This change extracts the JUnit reading into its own module (`JunitResultReader`) that takes the existing `XmlReader` as a dependency. With both seams injectable, we can write social tests that exercise the real `JunitResultReader` against a stub `XmlReader` returning crafted trees — no XML parsing, no filesystem, no async context needed.

## What Changes

- Add a new module `lua/neotest-java/core/junit_result_reader.lua` that knows the JUnit XML shape: takes paths → returns `JunitResult[]` (with the existing per-file parse-error logging and skip behavior)
- `JunitResultReader` accepts `XmlReader` as a dependency (DI), defaulting to one constructed with default `read_file` / `xml_parse`
- Migrate `result_builder.lua` to take `JunitResultReader` as a `ResultBuilderDeps` field (injected, not constructed internally); the local `load_all_testcases` function is removed
- Add unit tests for `JunitResultReader` using stub `XmlReader` instances that return crafted parsed trees
- Add "social" integration tests that wire a real `JunitResultReader` against a stub `XmlReader` to cover tree shapes that would otherwise require elaborate XML fixtures (single testcase, no testcase, malformed-equivalent, nested suites, etc.)

## Capabilities

### New Capabilities
- `junit-result-reader`: A testable reader for JUnit XML report files. Takes an `XmlReader` (and optionally a logger + tempname) as dependencies, walks `testsuite.testcase` and returns JunitResult objects. Decoupled from the XML parsing layer so the JUnit walk can be unit-tested with pre-parsed trees.

### Modified Capabilities
<!-- No existing spec deltas — this is a new capability layered on top of xml-reader -->

## Impact

- `lua/neotest-java/core/junit_result_reader.lua`: New module
- `lua/neotest-java/core/result_builder.lua`: Drops `load_all_testcases`; takes `junit_result_reader` as a new field in `ResultBuilderDeps` (a pre-built `JunitResultReader` instance); calls `deps.junit_result_reader.read_all(paths)` from `build_results`. No more direct `XmlReader` reference.
- `tests/unit/test_junit_result_reader_spec.lua`: New unit test suite — covers happy path, missing testsuite, missing testcase, single testcase wrapped in a table, empty file, parser error
- `tests/unit/test_junit_result_reader_social_spec.lua`: New social/integration test suite — real `JunitResultReader` against a stub `XmlReader` returning various tree shapes
- `tests/unit/test_result_builder_spec.lua`: Existing tests pass a stub `junit_result_reader` (returning whatever the test wants from `read_all`); they no longer need to hand-roll XML strings to drive `read_file`
- Whoever wires up `ResultBuilder` at the call site (the strategy dispatcher in `init.lua`) now constructs and passes a `JunitResultReader` — a one-line addition
