# groovy-test-discovery Specification

## Purpose

TBD - created by archiving change add-groovy-spock-support.
Update Purpose after archive.

## Requirements

### Requirement: Groovy test file discovery

The system SHALL discover test files with `.groovy` extension
using the same naming conventions as Java test files
(e.g., `*Test.groovy`, `*Spec.groovy`, `*IT.groovy`).

#### Scenario: Discover Spock specification file

- **WHEN** a file named `UserServiceSpec.groovy` exists in
  `src/test/groovy/`
- **THEN** the system includes it in the list of discoverable
  test files

#### Scenario: Discover Groovy test file

- **WHEN** a file named `OrderServiceTest.groovy` exists in
  `src/test/groovy/`
- **THEN** the system includes it in the list of discoverable
  test files

#### Scenario: Discover Groovy integration test file

- **WHEN** a file named `PaymentIT.groovy` exists in
  `src/test/groovy/`
- **THEN** the system includes it in the list of discoverable
  test files

#### Scenario: Ignore non-test Groovy files

- **WHEN** a file named `UserService.groovy` exists
  (no test suffix)
- **THEN** the system does NOT include it in the list of
  discoverable test files

### Requirement: Groovy file patterns exported

The patterns modules SHALL export `GROOVY_TEST_FILE_PATTERNS`
and `GROOVY_TEST_FILE_REGEXES` constants for use by file
discovery components.

#### Scenario: Groovy file patterns match .groovy extension

- **WHEN** `GROOVY_TEST_FILE_PATTERNS` is evaluated against
  `UserServiceSpec.groovy`
- **THEN** the pattern `Spec%.groovy$` matches the filename

#### Scenario: Groovy regex patterns match test class names

- **WHEN** `GROOVY_TEST_FILE_REGEXES` is evaluated against
  `UserServiceSpec`
- **THEN** the regex `^.*Spec$` matches the class name

### Requirement: Backward compatibility with Java tests

The system SHALL continue to discover and run `.java` test
files unchanged after Groovy support is added.

#### Scenario: Java test files still discovered

- **WHEN** a file named `UserServiceTest.java` exists in
  `src/test/java/`
- **THEN** the system includes it in the list of discoverable
  test files

#### Scenario: Mixed Java and Groovy projects

- **WHEN** a project contains both `UserServiceTest.java`
  and `OrderServiceSpec.groovy`
- **THEN** the system discovers both files
