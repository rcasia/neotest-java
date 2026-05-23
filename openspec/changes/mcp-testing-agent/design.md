## Context

OpenCode supports custom subagents and MCP servers via `opencode.json`. The Neovim MCP server (already available in the OpenCode ecosystem) exposes Neovim's buffer editing, command execution, file operations, and search capabilities as MCP tools. Docker provides lightweight, reproducible environments with clean state and full isolation.

By combining these, each test scenario runs in its own Docker container with a pinned Neovim version, JDK, build tool, and neotest-java. The agent spins up a container, connects via the Neovim MCP server, runs the scenario, tears down the container, and reports results. Multiple scenarios can run in parallel in separate containers.

Currently, neotest-java has:

- Unit tests (busted/plenary) in `tests/unit/`
- E2E tests (headless Neovim + Maven) in `tests/e2e/`
- Test fixtures in `tests/fixtures/` (e.g., `maven-simple`)
- A `.opencode/opencode.json` config file with no MCP or subagent configuration

## Goals / Non-Goals

**Goals:**

- Build a Docker image (`neotest-java-tester`) with Neovim, JDK, Maven, and neotest-java pre-installed
- Provide a container lifecycle script (`scripts/mcp-test-runner.sh`) to start/stop containers per scenario
- Configure the Neovim MCP server in `opencode.json` to connect to containerized Neovim
- Define a `neotest-java-tester` subagent with a prompt that drives manual testing via MCP
- Create a library of manual test scenarios with step-by-step agent instructions
- Support multiple parallel containers for concurrent scenario execution
- Pre-compile test fixtures into the Docker image so containers start ready to test

**Non-Goals:**

- Not replacing existing unit or E2E tests
- Not modifying neotest-java source code (only OpenCode config, Docker, and test infrastructure)
- Not adding new test fixtures unless necessary for scenarios not covered by existing ones
- Not automating CI integration of the agent (future concern)

## Decisions

**1. Use the existing Neovim MCP server rather than building a custom one**

- The OpenCode ecosystem already provides a Neovim MCP server with tools for buffer editing, command execution, search, etc.
- Rationale: Zero additional server code. The server is battle-tested and maintained.
- Alternative considered: Building a custom testing MCP server. Rejected — would duplicate effort and add maintenance burden.

**2. Docker container per scenario, not per test**

- Each invocation of `mcp-test-runner.sh --scenario <name>` creates a single container, runs the full scenario, then destroys it.
- Rationale: Clean state is guaranteed; parallel scenarios are naturally isolated.
- Alternative considered: Long-running containers with snapshots. Rejected — adds complexity without clear benefit for manual testing.

**3. Fixtures compiled at Docker image build time, not at container startup**

- The Dockerfile compiles all test fixtures during `docker build`. Containers start with pre-compiled classes.
- Rationale: Zero wait time when the agent runs a scenario — containers are ready instantly.
- Alternative considered: Compiling fixtures in an entrypoint script. Rejected — adds startup delay and complicates caching.

**4. Agent-driven container lifecycle via script, not inline Docker commands**

- The agent invokes `scripts/mcp-test-runner.sh` which handles `docker run`, port mapping, container name, and teardown.
- Rationale: The agent prompt stays simple (no Docker CLI knowledge needed). The script enforces conventions.
- Alternative considered: Agent runs Docker commands directly. Rejected — error-prone, harder to maintain, couples agent to Docker CLI details.

**5. Test scenarios defined as markdown files that the agent reads as context**

- The agent prompt will instruct it to load scenario files from a known directory.
- Rationale: Scenarios are easy to write, version-control, and extend without changing agent configuration.
- Alternative considered: Hard-coding scenarios in the agent prompt. Rejected — would make the prompt bloated and harder to maintain.

**6. Agent prompt uses a "plan-act-report" loop pattern**

- The agent plans which test to run, acts by driving containerized Neovim via MCP, then reports results back to the user.
- Rationale: Provides a structured, predictable workflow that is easy to follow and debug.
- Alternative considered: Free-form interaction. Rejected — too ambiguous for consistent results.

**7. MCP server connects to a specific container port, configured per run**

- `mcp-test-runner.sh` assigns a unique host port per container and writes the connection details to a JSON file the MCP server reads.
- Rationale: Enables multiple containers on different ports without port conflicts.
- Alternative considered: Fixed port per container. Rejected — prevents parallel runs.

## Risks / Trade-offs

- **Docker dependency**: The agent cannot function without Docker installed and running → Mitigation: The runner script checks `docker info` before proceeding; clear error messages guide the user.
- **Docker image size**: Including JDK, Maven, Neovim, and all fixtures creates a large image → Mitigation: Use a slim base image (e.g., `alpine`); build multi-stage to keep the final image lean.
- **Container startup latency**: Docker start takes 1-3 seconds → Mitigation: Acceptable for manual testing; fixtures are pre-compiled so no additional wait.
- **Multiple containers resource usage**: Each container uses memory for Neovim + JVM → Mitigation: Containers are short-lived (seconds to minutes); limit to 4 concurrent containers via runner script.
- **Fixture environment drift**: Test fixtures must be recompiled when the Docker image is rebuilt → Mitigation: Add a Makefile target for `make docker-test-image` that is run before testing sessions.
