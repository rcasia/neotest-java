## ADDED Requirements

### Requirement: Scenario library directory exists

The system SHALL create a `tests/manual-scenarios/` directory containing markdown files, one per test scenario, that the agent can load as context before executing.

#### Scenario: Scenario files accessible

- **WHEN** the agent reads files from `tests/manual-scenarios/`
- **THEN** it SHALL find organized scenario files with step-by-step instructions

### Requirement: Basic test discovery scenario

The scenario library SHALL include a scenario for verifying that neotest-java discovers test files correctly in a Maven project.

#### Scenario: Test discovery in maven-simple

- **WHEN** the agent follows the "test-discovery" scenario steps
- **THEN** it SHALL open a test file from `tests/fixtures/maven-simple/` and verify that neotest-java's `is_test_file` returns `true` for it and `false` for a non-test file

### Requirement: Test execution scenario (pass/fail)

The scenario library SHALL include a scenario for running tests and verifying that passing tests report as passed and failing tests report as failed.

#### Scenario: Run tests and verify results

- **WHEN** the agent follows the "test-execution" scenario steps
- **THEN** it SHALL trigger neotest to run tests on a file with known pass/fail methods and verify the results match expectations

### Requirement: Parameterized test scenario

The scenario library SHALL include a scenario for testing parameterized test discovery and execution.

#### Scenario: Parameterized test handling

- **WHEN** the agent follows the "parameterized-test" scenario steps
- **THEN** it SHALL verify that parameterized tests are discovered as individual test positions and that running them produces correct results

### Requirement: Debugging scenario

The scenario library SHALL include a scenario for verifying that nvim-dap debugging integration works.

#### Scenario: Debug test

- **WHEN** the agent follows the "debug-test" scenario steps
- **THEN** it SHALL verify that neotest-java generates correct debug commands and that breakpoints can be set

### Requirement: Multi-module project scenario

The scenario library SHALL include a scenario for testing multi-module project support.

#### Scenario: Multi-module test execution

- **WHEN** the agent follows the "multi-module" scenario steps
- **THEN** it SHALL verify that tests in submodules are correctly discovered and can be executed
