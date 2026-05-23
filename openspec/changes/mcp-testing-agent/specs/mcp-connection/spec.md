## ADDED Requirements

### Requirement: MCP server configured in opencode.json

The system SHALL configure the Neovim MCP server in `.opencode/opencode.json` with a `command` and `args` that connect to a Docker container running Neovim.

#### Scenario: MCP config exists

- **WHEN** the user inspects `.opencode/opencode.json`
- **THEN** it SHALL contain an `mcpServers` entry named `neotest-java-tester` with valid `command` and `args`

#### Scenario: Connects to containerized Neovim

- **WHEN** a Docker container is running with Neovim and the MCP server configuration points to its host port
- **THEN** the MCP server SHALL successfully establish a connection to Neovim inside the container

### Requirement: Dynamic port support

The MCP server configuration SHALL support connecting to containers on dynamically assigned ports (read from the runner script's JSON output or a config file).

#### Scenario: Port from runner output

- **WHEN** `scripts/mcp-test-runner.sh --start` outputs a JSON with a `hostPort` field
- **THEN** the MCP server SHALL be able to connect using that port

### Requirement: Health check

The system SHALL be able to verify that the containerized Neovim has neotest-java loaded and ready.

#### Scenario: Health check succeeds

- **WHEN** the agent sends a health check command to the containerized Neovim via the MCP server
- **THEN** the response SHALL indicate that neotest-java is loaded and available
