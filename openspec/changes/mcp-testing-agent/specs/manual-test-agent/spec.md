## ADDED Requirements

### Requirement: Agent is defined in opencode.json

The system SHALL define a `neotest-java-tester` subagent in `.opencode/opencode.json` under the `agent` configuration with a prompt that instructs it how to manually test neotest-java features using the Neovim MCP server.

#### Scenario: Agent exists in config

- **WHEN** the user lists available subagents in OpenCode
- **THEN** `neotest-java-tester` SHALL appear in the list with a description

### Requirement: Agent follows plan-act-report workflow

The agent SHALL follow a structured "plan-act-report" loop: plan which test scenario to run, act by driving Neovim via MCP tools, and report results back to the user.

#### Scenario: Agent runs a test scenario

- **WHEN** the user asks the agent to test a specific feature
- **THEN** the agent SHALL:
  - Load the corresponding scenario file as context
  - Execute the steps via Neovim MCP tools
  - Report the outcome (pass/fail) with evidence

#### Scenario: Agent reports failure clearly

- **WHEN** a test step fails (e.g., test count mismatch, error in Neovim output)
- **THEN** the agent SHALL report the failure, the actual vs expected values, and any error messages from Neovim

### Requirement: Agent manages container lifecycle

The agent SHALL use `scripts/mcp-test-runner.sh` to start a Docker container for each test scenario, wait for it to be ready, and tear it down after the scenario completes.

#### Scenario: Start container for scenario

- **WHEN** the user asks to test a specific feature
- **THEN** the agent SHALL run `scripts/mcp-test-runner.sh --scenario <name>` to start a container

#### Scenario: Container teardown after scenario

- **WHEN** a test scenario completes (pass or fail)
- **THEN** the agent SHALL tear down the container by running `scripts/mcp-test-runner.sh --stop <container-id>`

### Requirement: Agent checks prerequisites before running

The agent SHALL verify that Docker is available and the `neotest-java-tester` Docker image exists before attempting to run any scenario.

#### Scenario: Docker not available

- **WHEN** Docker is not installed or the daemon is not running
- **THEN** the agent SHALL report the missing prerequisite and guide the user on how to install/start Docker

#### Scenario: Docker image not found

- **WHEN** the `neotest-java-tester` image is not present locally
- **THEN** the agent SHALL run `make docker-test-image` to build it, or guide the user to do so

### Requirement: Agent supports parallel scenarios

The agent SHALL be able to run multiple scenarios concurrently by starting separate containers for each.

#### Scenario: Concurrent scenario execution

- **WHEN** the user requests two different test scenarios
- **THEN** the agent SHALL start two separate containers, each running a Neovim instance, and execute both scenarios independently
