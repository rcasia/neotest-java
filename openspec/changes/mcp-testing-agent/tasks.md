## 1. Build Docker image

- [ ] 1.1 Create `Dockerfile.test` with a multi-stage build: base → install JDK, Maven, Neovim → copy neotest-java and fixtures → compile fixtures → set up minimal Neovim config
- [ ] 1.2 Add a `.dockerignore` excluding `deps/`, `pack/`, `.git/`, and other unnecessary build artifacts
- [ ] 1.3 Create minimal Neovim init config for the container (`docker/init.lua`) that loads neotest-java, neotest, and sets up the MCP server
- [ ] 1.4 Add `Makefile` target `docker-test-image` that builds the Docker image as `neotest-java-tester:latest`
- [ ] 1.5 Build the image and verify it starts Neovim correctly inside the container

## 2. Create container runner script

- [ ] 2.1 Create `scripts/mcp-test-runner.sh` with `--start`, `--stop`, and `--list` commands
- [ ] 2.2 Implement `--start`: validate Docker/image, start container with unique port mapping, wait for Neovim readiness, output connection JSON (container ID, host port)
- [ ] 2.3 Implement `--stop`: accept container ID, stop and remove container gracefully
- [ ] 2.4 Implement `--list`: list running test containers with their ports and scenarios
- [ ] 2.5 Create `tests/fixtures/fixtures.json` registry mapping fixture names to paths and descriptions

## 3. Configure Neovim MCP server connection

- [ ] 3.1 Add `mcpServers` entry to `.opencode/opencode.json` for the Neovim MCP server configured to connect to the containerized Neovim
- [ ] 3.2 Configure `mcp-test-runner.sh --start` to output a connection config file that the MCP server can consume (or use a dynamic port approach)
- [ ] 3.3 Verify MCP server connects to a running container and responds to health check

## 4. Define the neotest-java-tester subagent

- [ ] 4.1 Add the `neotest-java-tester` subagent definition under `agent` in `.opencode/opencode.json` with `description` and `prompt`
- [ ] 4.2 Write the agent prompt with: prerequisites check (Docker + image), container lifecycle workflow, plan-act-report loop, scenario file loading instructions, failure reporting format
- [ ] 4.3 Wire the agent to have access to the Neovim MCP server tools (read buffer, write buffer, command exec, file operations)

## 5. Write manual test scenario files

- [ ] 5.1 Create `tests/manual-scenarios/` directory
- [ ] 5.2 Write `tests/manual-scenarios/test-discovery.md` — steps to verify `is_test_file` returns correct results for Java test and non-test files via containerized Neovim
- [ ] 5.3 Write `tests/manual-scenarios/test-execution.md` — steps to run tests and verify pass/fail results match expectations
- [ ] 5.4 Write `tests/manual-scenarios/parameterized-test.md` — steps to verify parameterized test discovery and execution
- [ ] 5.5 Write `tests/manual-scenarios/debug-test.md` — steps to verify nvim-dap debug command generation and breakpoint setting
- [ ] 5.6 Write `tests/manual-scenarios/multi-module.md` — steps to verify multi-module test discovery and execution

## 6. Documentation and final wiring

- [ ] 6.1 Add a `tests/manual-scenarios/README.md` explaining how to use the agent, prerequisites (Docker), and workflow
- [ ] 6.2 Verify all scenario files are loadable and the agent prompt references them correctly
- [ ] 6.3 Do a dry-run: ask the agent to start a container, run a test scenario, and tear it down
- [ ] 6.4 Test parallel execution: run two scenarios concurrently in separate containers
- [ ] 6.5 Fix any issues found during the dry-run
