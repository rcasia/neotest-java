## ADDED Requirements

### Requirement: Scenario directory exists

The system SHALL create a `tests/manual-scenarios/` directory containing markdown files, one per test scenario, that the agent loads as context before executing.

#### Scenario: Files are accessible

- **WHEN** the agent reads files from `tests/manual-scenarios/`
- **THEN** it SHALL find organized scenario files with step-by-step instructions

### Requirement: Test discovery scenario

`tests/manual-scenarios/test-discovery.md` SHALL describe steps to verify that neotest-java discovers Java test files correctly.

#### Scenario: Test discovery in maven-simple

- **WHEN** the agent follows `test-discovery.md`
- **THEN** it SHALL open a test file from `tests/fixtures/maven-simple/` and verify that neotest-java's `is_test_file` returns true for test files and false for non-test files

### Requirement: Test execution scenario

`tests/manual-scenarios/test-execution.md` SHALL describe steps to run tests and verify pass/fail results.

#### Scenario: Run and verify results

- **WHEN** the agent follows `test-execution.md`
- **THEN** it SHALL trigger neotest to run tests on a file with known pass/fail methods and verify results match expectations

### Requirement: Parameterized test scenario

`tests/manual-scenarios/parameterized-test.md` SHALL describe steps to verify parameterized test discovery and execution.

#### Scenario: Parameterized tests work

- **WHEN** the agent follows `parameterized-test.md`
- **THEN** it SHALL verify that parameterized tests are discovered as individual test positions and that running them produces correct results

### Requirement: Debugging scenario

`tests/manual-scenarios/debug-test.md` SHALL describe steps to verify nvim-dap debugging integration.

#### Scenario: Debug commands work

- **WHEN** the agent follows `debug-test.md`
- **THEN** it SHALL verify that neotest-java generates correct debug commands and breakpoints can be set

### Requirement: Multi-module scenario

`tests/manual-scenarios/multi-module.md` SHALL describe steps to verify multi-module project support.

#### Scenario: Multi-module tests work

- **WHEN** the agent follows `multi-module.md`
- **THEN** it SHALL verify that tests in submodules are correctly discovered and can be executed
