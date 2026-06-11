# junit-result-reader

## Purpose

TBD — describe the capability at a high level (what it does, where it fits in the system, who its primary consumers are).

## Requirements

### Requirement: Read JUnit results from report files

The JunitResultReader MUST read a list of JUnit XML report files, walk the `testsuite.testcase` structure, and return a flat array of `JunitResult` objects representing the testcases found across all files.

#### Scenario: Multiple testcases in one file
- **WHEN** `read_all` is called with a single file containing a `<testsuite>` with three `<testcase>` elements
- **THEN** the result is an array of three `JunitResult` objects, one per testcase

#### Scenario: Multiple files
- **WHEN** `read_all` is called with two files, each containing one `<testcase>` in a `<testsuite>`
- **THEN** the result is an array of two `JunitResult` objects

### Requirement: Tolerate missing or empty JUnit structures

The JunitResultReader MUST skip files whose XML does not contain a `testsuite` or whose `testsuite` has no `testcase` elements, returning an empty result for that file rather than throwing.

#### Scenario: File with no testsuite
- **WHEN** `read_all` is called with a file whose parsed tree has no `testsuite` key
- **THEN** the file contributes zero results to the output and no error is raised

#### Scenario: File with testsuite but no testcase
- **WHEN** `read_all` is called with a file whose `testsuite` has no `testcase` children
- **THEN** the file contributes zero results to the output and no error is raised

#### Scenario: Empty paths list
- **WHEN** `read_all` is called with an empty list
- **THEN** the result is an empty array

### Requirement: Wrap a single testcase in an array

The JunitResultReader MUST handle the case where a `<testsuite>` contains a single `<testcase>` (the parser returns it as a single table, not an array) by treating it the same as an array with one element.

#### Scenario: Single testcase element
- **WHEN** the parsed tree has `testsuite.testcase` as a single table (not an array)
- **THEN** `read_all` produces one `JunitResult` for that testcase

### Requirement: Surface parser errors as skipped files with a warning

The JunitResultReader MUST treat a parse error from the injected `XmlReader` as a recoverable condition: log a warning, skip the offending file, and continue with the remaining files.

#### Scenario: File with parse error
- **WHEN** the injected `XmlReader.parse` returns an `error` for a filepath
- **THEN** that filepath contributes zero results to the output
- **AND** a warning is logged with the filepath and the error message
- **AND** other files in the list are still processed

#### Scenario: One file fails, another succeeds
- **WHEN** `read_all` is called with two files and only the first produces a parse error
- **THEN** the result includes the testcases from the second file but none from the first
- **AND** a warning is logged for the first file

### Requirement: Dependency injection of XmlReader and tempname

The JunitResultReader MUST accept an `XmlReader` instance and a `tempname` function as injectable dependencies, so the JUnit walk can be unit-tested with pre-parsed trees and a controlled tempname generator.

#### Scenario: Reader with stub XmlReader
- **WHEN** the reader is constructed with a stub `xml_reader` whose `parse` returns a crafted tree
- **THEN** `read_all` uses the stubbed tree and never invokes the real `XmlReader`

#### Scenario: Reader with stub tempname
- **WHEN** the reader is constructed with a stub `tempname_fn`
- **THEN** each returned `JunitResult` was constructed using the stubbed tempname (no real `nio.fn.tempname` call)

#### Scenario: Default XmlReader when not provided
- **WHEN** the reader is constructed with no `xml_reader` dep
- **THEN** a default `XmlReader` (with default `read_file` / `xml_parse`) is created and used
