# Manual Test Scenarios for neotest-java

This directory contains manual test scenarios that the `neotest-java-tester`
OpenCode agent can execute to validate neotest-java features.

## Prerequisites

- **Docker**: Must be installed and running (e.g., `colima start` or Docker Desktop)
- **Docker image**: Build with `make docker-test-image` to create
  the `neotest-java-tester:latest` image
- **OpenCode**: The `neotest-java-tester` subagent must be configured in `.opencode/opencode.json`

## How It Works

1. The agent starts a Docker container with Neovim + neotest-java + JDK
   - compiled test fixtures
2. The agent connects to the containerized Neovim via the Neovim MCP server
3. The agent follows the scenario steps, driving Neovim through MCP tools
4. After completing the scenario, the agent tears down the container

## Scenarios

| File | Description |
|------|-------------|
| `test-discovery.md` | Verify neotest-java discovers Java test files correctly |
| `test-execution.md` | Run tests and verify pass/fail results |
| `parameterized-test.md` | Verify parameterized test discovery and execution |
| `debug-test.md` | Verify debug command generation and nvim-dap integration |
| `multi-module.md` | Verify multi-module project support |

## Running a Scenario

To run a scenario manually with the agent:

```text
@neotest-java-tester test the test-discovery scenario
```

Or run a specific feature:

```text
@neotest-java-tester I want to verify that neotest-java discovers test files correctly
```

## Container Management

The agent uses `scripts/mcp-test-runner.sh` for container lifecycle:

```bash
# Start a container
./scripts/mcp-test-runner.sh --start --fixture maven-simple

# Stop a container
./scripts/mcp-test-runner.sh --stop <container-id>

# List running containers
./scripts/mcp-test-runner.sh --list
```
