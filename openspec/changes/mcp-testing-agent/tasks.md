## 1. docker-test-image — Dockerfile.test + docker/init.lua

- [ ] 1.1 Create `Dockerfile.test` with multi-stage build: base image → install JDK, Maven, Neovim → copy neotest-java and fixtures → compile fixtures (`mvnw clean test-compile`) → set up minimal Neovim config
- [ ] 1.2 Create `docker/init.lua` — minimal Neovim config loading neotest-java, neotest, nvim-nio, plenary.nvim
- [ ] 1.3 Create `.dockerignore` excluding `deps/`, `pack/`, `.git/`, `node_modules/`, `.docker/`
- [ ] 1.4 Build the image and verify Neovim starts correctly inside the container

## 2. container-runner — scripts/mcp-test-runner.sh

- [ ] 2.1 Create `scripts/mcp-test-runner.sh` with `--start`, `--stop`, `--list` subcommands
- [ ] 2.2 Implement `--start`: validate Docker + image, start container with unique host port, wait for Neovim readiness, output JSON with `containerId`, `hostPort`, `fixture`
- [ ] 2.3 Implement `--stop <id>`: stop and remove container gracefully
- [ ] 2.4 Implement `--list`: list running test containers with ID, port, fixture
- [ ] 2.5 Add `docker-test-image` target to `Makefile`

## 3. mcp-connection — .opencode/opencode.json

- [ ] 3.1 Add `mcpServers` entry in `.opencode/opencode.json` for Neovim, configured to connect to containerized instances on dynamic ports
- [ ] 3.2 Verify MCP server connects to a running container and responds to health check

## 4. testing-agent — .opencode/opencode.json subagent

- [ ] 4.1 Add `neotest-java-tester` subagent under `agent` in `.opencode/opencode.json` with `description` and `prompt`
- [ ] 4.2 Write the agent prompt: prerequisites (Docker + image), container lifecycle via runner script, plan-act-report loop, load scenario files from `tests/manual-scenarios/`, failure reporting format, parallel execution support
- [ ] 4.3 Wire agent access to Neovim MCP server tools

## 5. scenario-files — tests/manual-scenarios/*.md

- [ ] 5.1 Create `tests/manual-scenarios/` directory
- [ ] 5.2 Write `tests/manual-scenarios/test-discovery.md` — steps to open a test/non-test file and verify `is_test_file` results
- [ ] 5.3 Write `tests/manual-scenarios/test-execution.md` — steps to run tests and verify pass/fail results
- [ ] 5.4 Write `tests/manual-scenarios/parameterized-test.md` — steps to verify parameterized test discovery and execution
- [ ] 5.5 Write `tests/manual-scenarios/debug-test.md` — steps to verify debug command generation and breakpoints
- [ ] 5.6 Write `tests/manual-scenarios/multi-module.md` — steps to verify multi-module test discovery and execution

## 6. fixture-registry — tests/fixtures/fixtures.json

- [ ] 6.1 Create `tests/fixtures/fixtures.json` with entries for all existing fixtures: `maven-simple`, and any others
- [ ] 6.2 Verify the runner script reads `fixtures.json` correctly when `--fixture` is specified

## 7. Documentation and final integration

- [ ] 7.1 Add a `tests/manual-scenarios/README.md` explaining prerequisites (Docker), how to build the image (`make docker-test-image`), and how to use the agent
- [ ] 7.2 Verify all scenario files are referenced correctly by the agent prompt
- [ ] 7.3 Dry-run: build image → start container → run a scenario → tear down → verify results
- [ ] 7.4 Test parallel execution: run two scenarios concurrently in separate containers
- [ ] 7.5 Fix any issues found during dry-run
