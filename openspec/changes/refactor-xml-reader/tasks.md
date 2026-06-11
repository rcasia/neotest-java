## 1. Create XML reader module

- [x] 1.1 Create `lua/neotest-java/util/xml_reader.lua` with `XmlReader = function(deps) return { read_tag = function(filepath, selector) ... end } end` — function-as-constructor returning an instance table (no class, no `new` method, no metatable), matching the existing `ResultBuilder = function(deps)` / `FileChecker = function(dependencies)` style
- [x] 1.2 Default `deps` (when nil) wire up `neotest.lib.file.read` and `neotest.lib.xml.parse`; `read_tag` walks the dotted-path selector and wraps `read_file`/`xml_parse` in `pcall` to surface errors as `{ value = nil, found = false, error = "..." }`
- [x] 1.3 Module exports `{ new = XmlReader, read_tag = default_instance.read_tag }` where `default_instance = XmlReader()` for callers that don't need DI
- [x] 1.4 Add Lua type annotations matching the pattern used in `lua/neotest-java/core/result_builder.lua` (`@class`, `@field`, `@param`, `@return`)
- [x] 1.5 Add a `parse(filepath) -> { tree, error }` method for callers that need to walk the full tree (`result_builder.lua`); `read_tag` is implemented on top of `parse` to keep read/parse logic in one place

## 2. Unit tests for XML reader

- [x] 2.1 Create `tests/unit/test_xml_reader_spec.lua` covering all spec scenarios: scalar at single-segment path, scalar at multi-segment path, missing tag, complex value, file-read error, parse error, stub dependencies, default dependencies, and the default-export shape
- [x] 2.2 Run `make test_unit` (or `tests/e2e/run.lua unit`) and confirm all new tests pass and no existing test regresses

## 3. Migrate `read_xml_tag` shim

- [ ] 3.1 Refactor `lua/neotest-java/util/read_xml_tag.lua` to instantiate with `XmlReader()` (default deps), call `read_tag` on the instance, and return `result.value` when `result.found` else `nil`. Preserve the global memoization wrapper
- [ ] 3.2 Run `tests/unit/test_maven_build_tool_spec.lua` to confirm the build-tool caller still works end-to-end

## 4. Wire `result_builder` through the new reader

- [x] 4.1 Replace the direct `xml.parse(data)` call at `lua/neotest-java/core/result_builder.lua:34` with a call into a reader instance built from the existing `deps.read_file`
- [x] 4.2 On `result.error`, log a warning via `log.warn` and skip the report file (return `{}`), matching the existing `read_file` failure behavior on lines 27-32
- [x] 4.3 Run `tests/unit/test_result_builder_spec.lua` and confirm the malformed-XML test (or add one if missing) passes

## 5. Verify

- [x] 5.1 Run the full unit test suite — all existing tests pass, new tests pass
- [x] 5.2 Run `luacheck` on the new and modified files to confirm no lint regressions
- [x] 5.3 Confirm `xml.parse` is no longer called outside `xml_reader.lua` (only `read_xml_tag.lua`'s defaults and `result_builder.lua`'s migrated call should reference it, and the latter should be removed)
