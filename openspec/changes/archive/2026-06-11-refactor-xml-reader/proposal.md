## Why

The current XML reader in `lua/neotest-java/util/read_xml_tag.lua` is not unit-testable in isolation: it hard-imports `neotest.lib.file` and `neotest.lib.xml` at module load time, memoizes results globally across all callers, and throws on malformed input. As a result, no unit tests cover it today, and `lua/neotest-java/core/result_builder.lua:34` calls `xml.parse` directly with no error handling — meaning a single malformed JUnit report crashes the entire result-building flow.

## What Changes

- Introduce a new `neotest-java.xml_reader` module that exposes a clean, injectable interface for reading XML files and querying values by dotted-path selector
- Inject `read_file` and `xml_parse` as dependencies so the module can be unit-tested with in-memory fixtures
- Return a structured result (`{ value, found, error }`) that distinguishes missing tags from complex values and surfaces parse/IO errors
- Add a comprehensive unit test suite for the new module
- Migrate `read_xml_tag.lua` to delegate to the new module (preserving the public API for `build_tool` callers)
- Wrap `result_builder.lua`'s direct `xml.parse` call with the new reader so malformed reports are skipped instead of crashing

## Capabilities

### New Capabilities
- `xml-reader`: A testable XML file reader with injectable I/O and parser dependencies, returning structured results for success/missing/error outcomes

### Modified Capabilities
<!-- No existing specs — this introduces the xml-reader capability as new -->

## Impact

- `lua/neotest-java/util/read_xml_tag.lua`: Refactor to delegate to `xml_reader`; preserve memoization behavior for current callers
- `lua/neotest-java/util/xml_reader.lua`: New module — pure logic with dependency injection
- `lua/neotest-java/core/result_builder.lua:34`: Replace direct `xml.parse` call with the new reader, so malformed reports are skipped with a logged warning
- `lua/neotest-java/build_tool/init.lua`: No change required (public `read_xml_tag` API preserved)
- `tests/unit/test_xml_reader_spec.lua`: New test suite — covers happy path, missing tag, complex value, file read error, and XML parse error scenarios
