## ADDED Requirements

### Requirement: Neovim MCP server configuration

The system SHALL configure the Neovim MCP server in `.opencode/opencode.json` with a transport type that connects to a Docker container running Neovim.

#### Scenario: MCP server is configured

- **WHEN** the user inspects `.opencode/opencode.json`
- **THEN** it SHALL contain an `mcpServers` entry for Neovim with a `command` and `args` that connect to the containerized Neovim

#### Scenario: MCP server connects to container

- **WHEN** a Docker container is running with Neovim and the MCP server config points to it
- **THEN** the MCP server SHALL successfully establish a connection to Neovim inside the container

### Requirement: Connection per container

Each test scenario container SHALL expose the Neovim MCP on a unique host port so multiple containers can run in parallel without port conflicts.

#### Scenario: Parallel containers on different ports

- **WHEN** two containers are started for two different test scenarios
- **THEN** each SHALL use a different host port and both SHALL be reachable via the MCP server simultaneously

### Requirement: Containerized Neovim loads neotest-java

The Docker image SHALL have neotest-java and its dependencies pre-installed so the containerized Neovim loads the plugin on startup.

#### Scenario: Health check on containerized Neovim

- **WHEN** the agent sends a health check command to the containerized Neovim via the MCP server
- **THEN** the response SHALL indicate that neotest-java is loaded and available

#### Scenario: Neovim opens a test fixture project

- **WHEN** the agent instructs containerized Neovim to open a file from a test fixture
- **THEN** Neovim SHALL open the file and neotest-java SHALL recognize it as a test file (if applicable)
