## 1. docker-test-image — Dockerfile.test + docker/init.lua

- [x] 1.1 Create `Dockerfile.test` with multi-stage build: base image → install JDK, Maven, Neovim → copy neotest-java and fixtures → compile fixtures (`mvnw clean test-compile`) → set up minimal Neovim config
- [x] 1.2 Create `docker/init.lua` — minimal Neovim config loading neotest-java, neotest, nvim-nio, plenary.nvim
- [x] 1.3 Create `.dockerignore` excluding `deps/`, `pack/`, `.git/`, `node_modules/`, `.docker/`
- [x] 1.4 Build the image and verify Neovim starts correctly inside the container

## 2. container-runner — scripts/mcp-test-runner.sh

- [x] 2.1 Create `scripts/mcp-test-runner.sh` with `--start`, `--stop`, `--list` subcommands
- [x] 2.2 Implement `--start`: validate Docker + image, start container with unique host port, wait for Neovim readiness, output JSON with `containerId`, `hostPort`, `fixture`
- [x] 2.3 Implement `--stop <id>`: stop and remove container gracefully
- [x] 2.4 Implement `--list`: list running test containers with ID, port, fixture
- [x] 2.5 Add `docker-test-image` target to `Makefile`

## 3. mcp-connection — .opencode/opencode.json

- [x] 3.1 Add `mcpServers` entry in `.opencode/opencode.json` for Neovim, configured to connect to containerized instances on dynamic ports
- [x] 3.2 Verify MCP server connects to a running container and responds to health check
- [x] 4.1 Add `neotest-java-tester` subagent under `agent` in `.opencode/opencode.json` with `description` and `prompt`
- [x] 4.2 Write the agent prompt: prerequisites (Docker + image), container lifecycle via runner script, plan-act-report loop, load scenario files from `tests/manual-scenarios/`, failure reporting format, parallel execution support
- [x] 4.3 Wire agent access to Neovim MCP server tools

## 5. scenario-files — tests/manual-scenarios/*.md

- [x] 5.1 Create `tests/manual-scenarios/` directory
- [x] 5.2 Write `tests/manual-scenarios/test-discovery.md` — steps to open a test/non-test file and verify `is_test_file` results
- [x] 5.3 Write `tests/manual-scenarios/test-execution.md` — steps to run tests and verify pass/fail results
- [x] 5.4 Write `tests/manual-scenarios/parameterized-test.md` — steps to verify parameterized test discovery and execution
- [x] 5.5 Write `tests/manual-scenarios/debug-test.md` — steps to verify debug command generation and breakpoints
- [x] 5.6 Write `tests/manual-scenarios/multi-module.md` — steps to verify multi-module test discovery and execution
- [x] 6.1 Create `tests/fixtures/fixtures.json` with entries for all existing fixtures: `maven-simple`, and any others
- [x] 6.2 Verify the runner script reads `fixtures.json` correctly when `--fixture` is specified

## 7. Documentation and final integration

- [x] 7.1 Add a `tests/manual-scenarios/README.md` explaining prerequisites (Docker), how to build the image (`make docker-test-image`), and how to use the agent
- [x] 7.2 Verify all scenario files are referenced correctly by the agent prompt
- [x] 7.3 Dry-run: build image → start container → run a scenario → tear down → verify results
- [x] 7.4 Test parallel execution: run two scenarios concurrently in separate containers
- [x] 7.5 Fix issues found during dry-run:
  - (a) `nvim_exec_autocmds('UIEnter', {})` needs 2nd arg (opts table) in Neovim 0.12
  - (b) `python3` via pyenv hangs — switched to `jq` for JSON parsing in runner script
  - (c) `get_unique_port()` race condition (both containers got port 18901) — switched to `-P` random ports
  - (d) Missing `EXPOSE 18901` in Dockerfile — `-P` only maps exposed ports
  - (e) Readiness check used `docker logs | grep UIEnter` which never matches — switched to `nc` TCP connect
