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

### Requirement: Agent checks prerequisites before running

The agent SHALL verify that the Neovim MCP server is running and the required fixture is set up before attempting any test scenario.

#### Scenario: Prerequisites not met

- **WHEN** the Neovim MCP server is not available
- **THEN** the agent SHALL report the missing prerequisite and guide the user on how to start it

#### Scenario: Fixture not compiled

- **WHEN** the test fixture is not yet compiled
- **THEN** the agent SHALL run `scripts/mcp-test-setup.sh` to compile it before proceeding
