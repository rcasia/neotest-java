## ADDED Requirements

### Requirement: Setup script exists

The system SHALL provide a `scripts/mcp-test-setup.sh` script that accepts a fixture name as an argument, compiles the fixture, resolves its classpath, and reports success or failure.

#### Scenario: Compile maven-simple fixture

- **WHEN** the script is invoked as `scripts/mcp-test-setup.sh maven-simple`
- **THEN** it SHALL run `./mvnw clean test-compile` in the fixture directory and exit with code 0

#### Scenario: Fixture not found

- **WHEN** the script is invoked with a non-existent fixture name
- **THEN** it SHALL print an error listing available fixtures and exit with code 1

#### Scenario: Prerequisites check

- **WHEN** the script starts
- **THEN** it SHALL verify that `$JAVA_HOME` is set and `java` is available before attempting compilation

### Requirement: Fixture registry

The system SHALL maintain a `tests/fixtures/fixtures.json` registry mapping fixture names to paths and descriptions so the agent can discover available fixtures.

#### Scenario: Agent lists fixtures

- **WHEN** the agent reads `tests/fixtures/fixtures.json`
- **THEN** it SHALL find entries for all available fixtures with their paths and descriptions
