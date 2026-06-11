## ADDED Requirements

### Requirement: Read scalar value from XML by dotted-path selector

The XML reader MUST resolve a dotted-path selector (e.g. `"project.build.directory"`) against a parsed XML document and return the scalar value at that path.

#### Scenario: Scalar value at single-segment path
- **WHEN** the reader is asked for selector `"artifactId"` on a POM whose `<artifactId>` is `"my-app"`
- **THEN** the result has `value = "my-app"`, `found = true`, and `error = nil`

#### Scenario: Scalar value at multi-segment path
- **WHEN** the reader is asked for selector `"project.build.directory"` on a POM whose `<project><build><directory>` is `"target"`
- **THEN** the result has `value = "target"`, `found = true`, and `error = nil`

### Requirement: Distinguish missing tag from complex value

The XML reader MUST allow callers to tell the difference between a tag that does not exist, a tag whose value is a complex (table) node, and a tag whose value is a scalar.

#### Scenario: Tag does not exist
- **WHEN** the selector traverses a segment that is absent from the XML
- **THEN** the result has `found = false`, `value = nil`, and `error = nil`

#### Scenario: Tag resolves to a complex node
- **WHEN** the selector resolves to a table (e.g. a parent element with child elements)
- **THEN** the result has `found = false`, `value = nil`, and `error = nil`

### Requirement: Surface I/O and parse errors

The XML reader MUST capture filesystem and parser errors in the result rather than throwing, so callers can decide how to react.

#### Scenario: File read fails
- **WHEN** the injected `read_file` returns an error for the given filepath
- **THEN** the result has `error` describing the read failure, `found = false`, and `value = nil`

#### Scenario: XML parse fails
- **WHEN** the injected `xml_parse` throws or returns `nil` for malformed input
- **THEN** the result has `error` describing the parse failure, `found = false`, and `value = nil`

### Requirement: Dependency injection for testability

The XML reader MUST accept `read_file` and `xml_parse` as injectable dependencies so that the module can be unit-tested without touching the real filesystem or parser.

#### Scenario: Reader works with stub dependencies
- **WHEN** the reader is constructed with stub `read_file` returning a string and stub `xml_parse` returning a fixed table
- **THEN** `read_tag` uses the stubs and returns a result derived from the stubbed data
- **AND** the real `neotest.lib.file` and `neotest.lib.xml` are never called

#### Scenario: Default dependencies wire up real libraries
- **WHEN** the reader is constructed with no `deps` argument (or with `deps = nil`)
- **THEN** the reader uses `neotest.lib.file.read` as `read_file` and `neotest.lib.xml.parse` as `xml_parse`

### Requirement: Backward-compatible default export

The XML reader module MUST expose a default `read_tag(filepath, selector): string | nil` function for callers that do not need structured results.

#### Scenario: Default export returns the scalar value
- **WHEN** the default export is called for a selector that resolves to `"target"`
- **THEN** it returns the string `"target"`

#### Scenario: Default export returns nil for missing tag
- **WHEN** the default export is called for a selector that does not resolve
- **THEN** it returns `nil`
