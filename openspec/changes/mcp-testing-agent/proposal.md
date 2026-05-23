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

- `docker-test-image`: Provides `Dockerfile.test` and `docker/init.lua` — a hermetic, reproducible Docker image with Neovim, JDK, Maven, and pre-compiled test fixtures
- `container-runner`: Provides `scripts/mcp-test-runner.sh` — manages container lifecycle (start, stop, list) with unique ports per container for parallel execution
- `mcp-connection`: Configures the Neovim MCP server in `.opencode/opencode.json` to connect to containerized Neovim instances on dynamically assigned ports
- `testing-agent`: Defines the `neotest-java-tester` OpenCode subagent with a plan-act-report prompt that drives container lifecycle and test scenarios
- `scenario-files`: Provides `tests/manual-scenarios/*.md` — step-by-step manual test scenarios (test discovery, execution, parameterized tests, debugging, multi-module)
- `fixture-registry`: Provides `tests/fixtures/fixtures.json` — a machine-readable registry mapping fixture names to paths

### Modified Capabilities
<!-- No existing specs are changing — this is purely additive -->

## Impact

### Deliverables Created

| File | Purpose |
|------|---------|
| `Dockerfile.test` | Multi-stage Docker image with Neovim, JDK, Maven, fixtures |
| `.dockerignore` | Excludes build artifacts from Docker context |
| `docker/init.lua` | Minimal Neovim config for containerized neotest-java |
| `scripts/mcp-test-runner.sh` | Container lifecycle manager |
| `.opencode/opencode.json` | MCP server config + `neotest-java-tester` subagent (updated) |
| `tests/manual-scenarios/*.md` | 5 scenario files (discovery, execution, parameterized, debug, multi-module) |
| `tests/fixtures/fixtures.json` | Machine-readable fixture registry |
| `Makefile` | New `docker-test-image` target (updated) |
