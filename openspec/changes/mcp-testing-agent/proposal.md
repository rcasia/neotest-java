## Why

Manual testing of neotest-java features currently requires a developer to open Neovim, configure the plugin, run tests, and visually inspect results. This is slow, inconsistent, and doesn't scale across multiple scenarios. Creating an OpenCode agent backed by the Neovim MCP server enables automated manual testing — the agent can drive Neovim, load neotest-java, execute test workflows, and report results, all from within the OpenCode conversation.

## What Changes

- Build a Docker image with Neovim + neotest-java + JDK + Maven/Gradle — hermetic, reproducible test environment
- Create a container lifecycle manager script (`scripts/mcp-test-runner.sh`) that spins up a Docker container for each test scenario and tears it down after
- Configure the Neovim MCP server to connect to the containerized Neovim instance
- Create a dedicated OpenCode subagent (`neotest-java-tester`) that uses the MCP server to interact with containerized Neovim
- Define manual test scenarios (test discovery, test execution, result reporting, debugging) as scenario files the agent loads as context
- Support multiple parallel test containers for concurrent scenario execution
- Document how to run manual tests via the agent

## Capabilities

### New Capabilities

- `mcp-neovim-connection`: Configure the Neovim MCP server in opencode.json, enabling OpenCode to send commands to and receive responses from a running Neovim instance
- `manual-test-agent`: Define the `neotest-java-tester` subagent with a prompt that instructs it how to manually test neotest-java features by driving Neovim through the MCP
- `test-scenario-library`: Catalog of manual test scenarios (test discovery, run pass/fail, parameterized tests, nested tests, debugging, multi-module projects) with step-by-step instructions the agent can follow
- `fixture-setup`: Test fixtures (currently in `tests/fixtures/`) organized so the agent can quickly set up the right project type for a given scenario

### Modified Capabilities
<!-- No existing specs are changing — this is purely additive -->

## Impact

- `.opencode/opencode.json`: Add MCP server configuration for Neovim and the new subagent definition
- `.opencode/agents/`: New directory with the `neotest-java-tester` agent definition
- `tests/fixtures/`: May need additional fixtures or documentation for agent-driven testing
- Documentation: New guide on how to use the agent for manual testing
