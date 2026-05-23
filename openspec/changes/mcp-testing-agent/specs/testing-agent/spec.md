## ADDED Requirements

### Requirement: Subagent defined in opencode.json

The system SHALL define a `neotest-java-tester` subagent in `.opencode/opencode.json` under the `agent` configuration with a `description` and `prompt`.

#### Scenario: Agent appears in list

- **WHEN** the user lists available subagents in OpenCode
- **THEN** `neotest-java-tester` SHALL appear with a description

### Requirement: Plan-act-report workflow

The agent SHALL follow a structured loop: plan which test scenario to run, act by driving containerized Neovim via MCP tools, and report results.

#### Scenario: Runs a scenario

- **WHEN** the user asks the agent to test a specific feature
- **THEN** the agent SHALL:
  - Run `scripts/mcp-test-runner.sh --start` to spin up a container
  - Load the corresponding scenario file from `tests/manual-scenarios/`
  - Execute the steps via Neovim MCP tools
  - Run `scripts/mcp-test-runner.sh --stop` to tear down the container
  - Report the outcome (pass/fail) with evidence

### Requirement: Prerequisites check

The agent SHALL verify that Docker is available and the `neotest-java-tester` image exists before attempting to run any scenario.

#### Scenario: Docker not available

- **WHEN** Docker is not installed or the daemon is not running
- **THEN** the agent SHALL report the missing prerequisite and guide the user on how to start Docker

#### Scenario: Image not found

- **WHEN** the `neotest-java-tester` image is not present locally
- **THEN** the agent SHALL run `make docker-test-image` to build it

### Requirement: Parallel scenario support

The agent SHALL be able to run multiple scenarios concurrently by starting separate containers for each.

#### Scenario: Two scenarios in parallel

- **WHEN** the user requests two different test scenarios
- **THEN** the agent SHALL start two separate containers with different ports and execute both scenarios independently
