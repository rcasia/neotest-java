## ADDED Requirements

### Requirement: Fixture registry exists

The system SHALL maintain a `tests/fixtures/fixtures.json` registry mapping fixture names to paths and descriptions so the agent and runner script can discover available fixtures.

#### Scenario: Registry is readable

- **WHEN** the agent reads `tests/fixtures/fixtures.json`
- **THEN** it SHALL find entries for all available fixtures with their paths and descriptions

#### Scenario: Runner script uses registry

- **WHEN** `scripts/mcp-test-runner.sh --start --fixture maven-simple` is run
- **THEN** the script SHALL look up the fixture path from `fixtures.json`

### Requirement: Registry format

`tests/fixtures/fixtures.json` SHALL be a JSON object where keys are fixture names (kebab-case) and values are objects with `path` and `description` fields.

#### Scenario: Fixture entry format

- **WHEN** `fixtures.json` is parsed
- **THEN** entries SHALL follow the format: `{ "maven-simple": { "path": "tests/fixtures/maven-simple", "description": "Single-module Maven project with JUnit 5" } }`
