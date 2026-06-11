## Context

`lua/neotest-java/util/read_xml_tag.lua` is the only XML reader in the codebase, used by `build_tool/init.lua` to read POM files. It is a 28-line module that:

- Hard-imports `neotest.lib.file` and `neotest.lib.xml` at module load
- Wraps `_read_xml_tag` in a global `memo` from `neotest.lib.func_util.memoize`
- Walks a dotted-path selector (`"project.build.directory"`) on the parsed XML tree
- Returns `nil` for: missing tag, complex (table) value, or any thrown error

The current `core/result_builder.lua` bypasses this helper entirely and calls `xml.parse` directly on each JUnit report file, with no error handling — a single malformed report crashes the result build.

The codebase already uses dependency injection as the dominant pattern (see `ResultBuilder`, `FileChecker`, `SpecBuilder`, and `tests/fake_build_tool.lua`), so an injectable reader fits the existing style.

## Goals / Non-Goals

**Goals:**

- Provide a single XML reader that can be unit-tested without touching the filesystem or the real `neotest.lib.xml` parser
- Return a structured result that lets callers distinguish "tag not found" from "value is a complex node" from "error"
- Keep the existing `read_xml_tag(filepath, selector) -> string | nil` API stable so `build_tool/init.lua` and its tests don't change
- Make `result_builder.lua` resilient to malformed JUnit reports

**Non-Goals:**

- Re-implementing or replacing the underlying `neotest.lib.xml` parser
- Changing the dotted-path selector semantics
- Adding XPath, namespaces, or streaming support
- Removing the memoization wrapper (keeping it preserves the existing cache behavior for build-tool callers)

## Decisions

### Decision 1: Function-as-constructor with injected dependencies

Expose the reader as a function that takes `deps` and returns an instance table — the exact pattern already used by `ResultBuilder`, `FileChecker`, `SpecBuilder`, etc.:

```lua
local XmlReader = function(deps)
  deps = deps or {}
  deps.read_file = deps.read_file or require("neotest.lib.file").read
  deps.xml_parse = deps.xml_parse or require("neotest.lib.xml").parse

  return {
    read_tag = function(filepath, selector)
      -- walks selector, wraps in pcall, returns { value, found, error }
    end,
  }
end
```

Callers instantiate with `local reader = XmlReader(deps)` and call `reader.read_tag(...)`. No class, no `new` method, no metatables — just a function returning a table. This matches `lua/neotest-java/core/result_builder.lua:82`, `lua/neotest-java/core/file_checker.lua:12`, and `lua/neotest-java/core/spec_builder/init.lua`.

Alternatives considered:

- **Class-style with `XmlReader.new(deps)` and `__index`** — slightly more "OO" but adds a metatable layer that the rest of the codebase doesn't use. Rejected for stylistic consistency.
- **Module-level functions** — matches the current `read_xml_tag.lua` style but blocks test injection. Rejected.
- **Global mutable state for injection** — works but is fragile and breaks in concurrent tests. Rejected.

### Decision 2: Structured `ReadResult` return value from `read_tag`

The instance's `read_tag` returns a table `{ value, found, error }`:

- `value`: the resolved value (string, number, or any scalar)
- `found`: `true` if a scalar value was resolved; `false` otherwise
- `error`: `string` describing I/O or parse failure, or `nil`

The **module's default export** at the bottom of `xml_reader.lua` is a convenience that returns a plain `string | nil` for callers that do not need structured results — see Decision 5.

Alternatives considered:

- **Throw on error, return nil on missing** — keeps API simple but loses the distinction and forces `pcall` at every call site. Rejected.
- **Return `value, err` as multiple values** — Lua-idiomatic but easy to misread. Rejected in favor of a single structured value.

### Decision 3: Preserve `read_xml_tag` as a thin shim

`util/read_xml_tag.lua` continues to export a `function(filepath, selector): string | nil`. Internally it instantiates the new reader with default deps, calls `read_tag`, and returns `result.value if result.found else nil`. The global memoization is preserved (it was solving a real problem: the build tool re-reads the same POM file in tight loops).

This means `build_tool/init.lua`, `test_maven_build_tool_spec.lua`, and any other caller of `read_xml_tag` require no changes.

### Decision 4: `result_builder` uses the new reader with error tolerance

Replace `xml.parse(data)` at `core/result_builder.lua:34` with a call to `reader.parse(filepath)`. The reader's `parse` method returns the full parsed tree on success or an error description, so `result_builder` can walk `tree.testsuite.testcase` as before without calling `xml.parse` directly. On `result.error` (malformed XML or read failure), log a warning via `log.warn` and skip the report file — matching the existing behavior for `read_file` failures on line 27-32.

We do **not** memoize JUnit report reads — each run produces fresh reports, and the existing code already deletes them at line 140-146.

### Decision 5: Default module export for one-shot callers

The `xml_reader` module exports a `read_tag(filepath, selector): string | nil` function built on top of a single shared default-deps instance, for callers that do not need DI:

```lua
-- at the bottom of xml_reader.lua
local default_reader = XmlReader()
return {
  new = XmlReader,                    -- for DI / unit tests
  read_tag = default_reader.read_tag, -- convenience for simple callers
}
```

The convenience function returns the scalar value, or `nil` if the tag is missing, the value is complex, or an error occurred. `util/read_xml_tag.lua` will use `XmlReader.new()` (with its own deps setup) rather than this convenience export, because it needs explicit control over the memoized instance.

### Decision 6: Expose `parse(filepath)` for full-tree callers

The reader exposes a `parse(filepath) -> { tree, error }` method alongside `read_tag`. This exists because some call sites (`result_builder.lua`) need to walk the full parsed tree rather than resolve a single scalar — and we want all XML parsing to flow through the same module so error handling stays consistent.

`read_tag` is implemented on top of `parse`: it parses, then walks the selector. This keeps the read/parse logic in one place.

## Risks / Trade-offs

- **[Risk] Two ways to parse XML after the change** — `xml.parse` is still imported directly in `result_builder.lua` if we don't fully migrate it. → **Mitigation**: migrate `result_builder.lua` in the same change so `xml.parse` is no longer called outside the new reader.
- **[Risk] `read_xml_tag` shim adds an indirection** — existing callers get one extra function call per POM read. → **Mitigation**: negligible cost; POM reads are not on a hot path and the memoization layer is preserved.
- **[Risk] Tests for the new module need fixtures** — the codebase has no existing XML fixtures. → **Mitigation**: define small inline XML strings in the test file (no new fixture directory needed); the project already uses this pattern in `test_junit_version_detector_spec.lua` and others.

## Migration Plan

1. Add `lua/neotest-java/util/xml_reader.lua` (new module)
2. Add `tests/unit/test_xml_reader_spec.lua` (new test suite)
3. Refactor `lua/neotest-java/util/read_xml_tag.lua` to delegate to the new module
4. Update `lua/neotest-java/core/result_builder.lua` to use the new reader with error tolerance
5. Run full unit test suite — no existing test should regress

Rollback: revert the four files. The public `read_xml_tag` API is unchanged, so rollback is safe.

## Open Questions

None — the proposal, design, and existing codebase patterns are sufficient to proceed.
