## ADDED Requirements

### Requirement: Neovim MCP server configuration

The system SHALL configure the Neovim MCP server in `.opencode/opencode.json` with a transport type and a command to launch a Neovim instance suitable for testing neotest-java.

#### Scenario: MCP server is configured

- **WHEN** the user inspects `.opencode/opencode.json`
- **THEN** it SHALL contain an `mcpServers` entry for Neovim with a valid `command` and `args`

#### Scenario: MCP server launches Neovim

- **WHEN** OpenCode starts and the MCP server configuration is valid
- **THEN** the Neovim MCP server SHALL launch a Neovim process that can receive MCP commands

### Requirement: Neovim instance is configured for neotest-java testing

The launched Neovim instance SHALL load neotest-java and its dependencies so the agent can interact with the plugin.

#### Scenario: Neovim loads neotest-java

- **WHEN** the agent sends a health check command to the Neovim MCP server
- **THEN** the response SHALL indicate that neotest-java is loaded and available

#### Scenario: Neovim opens a test fixture project

- **WHEN** the agent instructs Neovim to open a file from a test fixture
- **THEN** Neovim SHALL open the file and neotest-java SHALL recognize it as a test file (if applicable)
