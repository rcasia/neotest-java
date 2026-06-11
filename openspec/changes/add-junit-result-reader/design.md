## Context

`lua/neotest-java/core/result_builder.lua` currently has the JUnit-specific walking logic embedded in a private `load_all_testcases` function. The flow is:

1. `XmlReader({ read_file = read_file }).parse(filepath)` — read + parse XML
2. Walk `parsed.tree.testsuite.testcase` — JUnit-specific knowledge
3. Wrap each testcase in a `{ tc, tempname }` table for later JunitResult construction
4. Flat-map over all paths, skipping files with parse errors or missing testsuite/testcase

The JUnit walk (step 2) and the per-file skip/empty handling (step 4) are the part that knows the JUnit format. They're tangled with the orchestrator that already has the result_builder's main flow, and the only testable seam today is the underlying `read_file` function — meaning every test has to hand-roll an XML string and stub I/O. We can't test "what happens when the parser returns a tree with a single testcase" without producing a real XML string that has a single testcase.

The codebase already has a clean DI pattern (ResultBuilder, FileChecker, SpecBuilder, and now XmlReader from the previous change). The new module should fit the same style.

## Goals / Non-Goals

**Goals:**
- Extract the JUnit walk into `JunitResultReader` so the JUnit format is owned in one place
- Make the JUnit walk unit-testable with pre-parsed trees via DI of `XmlReader`
- Keep `result_builder.lua` focused on orchestration: scan → read all → group → merge → cleanup
- Cover JUnit edge cases (single testcase wrapped in a non-array, missing testcase, missing testsuite) that are currently untested
- Add a "social" test layer that wires the real `JunitResultReader` against a stub `XmlReader` to cover the tree shapes without touching XML strings

**Non-Goals:**
- Changing the `JunitResult` model or its parsing semantics
- Adding new test framework integrations or new test types
- Changing the public `ResultBuilder` shape (the existing `build_results` signature stays)
- Removing the `XmlReader` dependency in `result_builder.lua` — only adding a `JunitResultReader` dependency on top of it (or instead, if simpler)

## Decisions

### Decision 1: `JunitResultReader = function(deps)` factory, function-as-constructor

Same style as the rest of the codebase. The factory takes a deps table including `xml_reader` (an `XmlReader` instance) and optional `tempname_fn`, and returns an instance with `read_all(paths): JunitResult[]`.

```lua
local JunitResultReader = function(deps)
  deps = deps or {}
  -- default a fresh XmlReader if none provided
  deps.xml_reader = deps.xml_reader or XmlReader()
  deps.tempname_fn = deps.tempname_fn or nio.fn.tempname

  return {
    read_all = function(paths)
      -- walk each path, build JunitResult objects, skip on parse error
    end,
  }
end
```

**Alternatives considered:**
- Class-style with `JunitResultReader.new(deps)` and `__index` — rejected for consistency with the rest of the codebase
- Free functions that take a reader as the first arg — works but doesn't compose with the existing DI style and complicates swapping in tests
- Exposing `read_all` plus per-file `read_one` as separate methods — YAGNI for the current callers; one method is enough

### Decision 2: Return `JunitResult[]` directly (not wrapped in `{ tc, tempname }`)

The current `load_all_testcases` returns a list of `{ tc = testcase, tempname = tempname }` entries, which is then re-walked by `group_by_method_base` to build the actual `JunitResult` instances. The intermediate wrapping is an implementation detail.

The new `JunitResultReader.read_all` should construct the `JunitResult` objects directly and return `JunitResult[]` (a flat array). The `tempname` from the deps is used internally for `JunitResult:new(testcase, tempname)`.

This means `result_builder.lua` no longer needs `group_by_method_base` to do that wrapping — it can group the returned `JunitResult[]` directly. This is a small simplification.

### Decision 3: Two test layers — unit and social

- **Unit tests** (`test_junit_result_reader_spec.lua`): drive `JunitResultReader` with a stub `XmlReader` returning crafted trees. No XML strings, no filesystem, no async context. Cover the JUnit walk logic.
- **Social tests** (`test_junit_result_reader_social_spec.lua`): wire a real `JunitResultReader` against a stub `XmlReader` that returns the kinds of trees real JUnit reports produce. The "social" naming emphasizes that the unit under test is the combination, not just one component.

The existing `test_result_builder_spec.lua` keeps its current approach (string-XML stubs through `read_file`) — those tests still pass and still cover the I/O integration. The new social tests add coverage for tree-shape cases that XML strings are awkward to express.

### Decision 4: Where the parse-error logging goes

`JunitResultReader` does the logging (it owns the JUnit walk, so it knows when a parse error is "expected and recoverable"). `log.warn` with the filepath and the error message — same behavior as the current `load_all_testcases`.

The `log` module is also injected as a dep so tests can assert on the warn calls. Default is the project's real logger.

### Decision 5: `ResultBuilderDeps` takes `JunitResultReader` directly (not `xml_reader`)

Two shapes to consider:
- **A**: `ResultBuilderDeps` adds `xml_reader` directly; `result_builder.lua` constructs the `JunitResultReader` internally from `deps.xml_reader` + `deps.read_file` + `deps.tempname_fn`
- **B**: `ResultBuilderDeps` adds `junit_result_reader` (a pre-built instance); `result_builder.lua` calls `deps.junit_result_reader.read_all(paths)` directly

**Pick: B** — `JunitResultReader` is the dependency the consumer cares about, not the lower-level `xml_reader`. Putting the construction at the call site keeps `result_builder.lua` strictly an orchestrator with no factory logic, and it gives the consumer the right test seam: "swap the JUnit walk" rather than "swap the entire XML subsystem". Tests that want to bypass the JUnit walk entirely can pass a stub `JunitResultReader` returning pre-built `JunitResult[]` arrays.

The call-site wiring is trivial (one extra line: `JunitResultReader()`), and the test fixture is dramatically simpler — the existing `test_result_builder_spec.lua` tests can drop their hand-rolled XML strings and just hand back canned result arrays.

## Risks / Trade-offs

- **[Risk] New module adds a layer of indirection for a small amount of logic** → **Mitigation**: the JUnit walk is non-trivial (single-testcase wrap, per-file skip, parse-error logging) and is the kind of code that has historically been a source of bugs (see commit `c409208 fix(result): parse correctly result errors having '>' sign`). A focused module with focused tests is worth the indirection.
- **[Risk] Existing `test_result_builder_spec.lua` tests need to be updated for the new deps shape** → **Mitigation**: replace the hand-rolled `read_file` XML-string stubs with a stub `junit_result_reader` returning canned `JunitResult[]` arrays. Simpler and more focused than the current tests.
- **[Risk] The call site now has to know about both `XmlReader` and `JunitResultReader`** → **Mitigation**: a single line — `local jrr = JunitResultReader({ xml_reader = XmlReader() })` — at the strategy dispatch level. Construction logic is contained, and tests of `result_builder.lua` don't see it at all.

## Migration Plan

1. Add `lua/neotest-java/core/junit_result_reader.lua` (new module) + unit tests + social tests
2. Update `lua/neotest-java/core/result_builder.lua`: drop `load_all_testcases`, add `junit_result_reader` to `ResultBuilderDeps` as a pre-built instance, call `deps.junit_result_reader.read_all(paths)` from `build_results`
3. Update `tests/unit/test_result_builder_spec.lua` to pass a stub `junit_result_reader` (returning canned result arrays) instead of the current `read_file` + XML-string pattern
4. Update the call site in `lua/neotest-java/init.lua` to construct and pass a `JunitResultReader` (one extra line)
5. Run the full unit suite — all 126 existing tests pass (with simplified fixtures) + new ones pass

Rollback: revert the four files. The public `ResultBuilder.build_results` signature is unchanged, so the only consumers of this (the test suite and neotest's strategy dispatch) won't notice.

## Open Questions

None — the proposal, the existing codebase patterns, and the previous XmlReader change provide enough to proceed.
