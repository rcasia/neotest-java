## 1. Create JunitResultReader module

- [ ] 1.1 Create `lua/neotest-java/core/junit_result_reader.lua` with `JunitResultReader = function(deps) return { read_all = function(paths) ... end } end` — function-as-constructor returning an instance table, matching `ResultBuilder = function(deps)` / `XmlReader = function(deps)` style
- [ ] 1.2 Module takes `xml_reader`, `tempname_fn`, and `log` as injectable deps; defaults: `xml_reader = XmlReader()` (from the prior change), `tempname_fn = nio.fn.tempname`, `log = require("neotest-java.logger")`
- [ ] 1.3 `read_all(paths)` iterates paths, calls `xml_reader.parse(filepath)`, and on `parsed.error` calls `log.warn` and skips the file. On success, walks `parsed.tree.testsuite.testcase`, normalizes single-table testcase into an array, and constructs a `JunitResult` per testcase via `JunitResult:new(tc, tempname_fn)`
- [ ] 1.4 Add Lua type annotations matching the pattern in `lua/neotest-java/util/xml_reader.lua` (`@class`, `@field`, `@param`, `@return`)

## 2. Unit tests for JunitResultReader

- [ ] 2.1 Create `tests/unit/test_junit_result_reader_spec.lua` covering: multiple testcases in one file, multiple files, no testsuite, testsuite without testcase, single testcase (not an array), empty paths list, parse error per file, mixed pass-and-fail files. Drive with a stub `XmlReader` whose `parse` returns crafted trees
- [ ] 2.2 Run `bash scripts/test tests/unit/test_junit_result_reader_spec.lua` and confirm all tests pass

## 3. Social integration tests

- [ ] 3.1 Create `tests/unit/test_junit_result_reader_social_spec.lua` that wires a REAL `JunitResultReader` against a stub `XmlReader` returning tree shapes that mirror what real JUnit reports produce (the `xml2lua` parser's quirks: `_attr` subtables, `<system-out>` and `<system-err>` siblings, single-testcase wrap, nested failure elements)
- [ ] 3.2 Run `bash scripts/test tests/unit/test_junit_result_reader_social_spec.lua` and confirm the integration works

## 4. Migrate result_builder to use JunitResultReader

- [ ] 4.1 In `lua/neotest-java/core/result_builder.lua`: remove the local `load_all_testcases` function and the `XmlReader` import; add `junit_result_reader` to `ResultBuilderDeps`; call `deps.junit_result_reader.read_all(paths)` from `build_results`
- [ ] 4.2 In `lua/neotest-java/init.lua` (or wherever `ResultBuilder` is constructed at the call site): add `JunitResultReader({ xml_reader = XmlReader() })` to the deps passed to `ResultBuilder`. One extra line.
- [ ] 4.3 In `tests/unit/test_result_builder_spec.lua`: replace the hand-rolled `read_file` + XML-string stubs with a stub `junit_result_reader` returning canned `JunitResult[]` arrays. Simpler, more focused.
- [ ] 4.4 Run `bash scripts/test` — full unit suite green, including existing result_builder tests and the new junit_result_reader specs

## 5. Verify

- [ ] 5.1 `luacheck` clean on `lua/neotest-java/core/junit_result_reader.lua` and modified files
- [ ] 5.2 Run the full unit suite one more time
- [ ] 5.3 Confirm the public `ResultBuilder.build_results` signature is unchanged and that `result_builder.lua` no longer references `XmlReader` at all — only `JunitResultReader`
