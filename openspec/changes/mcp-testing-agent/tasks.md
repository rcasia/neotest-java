## 1. Configure Neovim MCP server

- [ ] 1.1 Add `mcpServers` entry to `.opencode/opencode.json` for the Neovim MCP server with appropriate `command` and `args`
- [ ] 1.2 Set the Neovim server args to load neotest-java and dependencies on startup (use `-c` or `--cmd` flags)
- [ ] 1.3 Verify the MCP server starts and responds to commands (health check via Neovim buffer tool)

## 2. Define the neotest-java-tester subagent

- [ ] 2.1 Add the `neotest-java-tester` subagent definition under `agent` in `.opencode/opencode.json` with `description` and `prompt`
- [ ] 2.2 Write the agent prompt with the "plan-act-report" workflow, instructions to load scenario files, prerequisite checks, and failure reporting format
- [ ] 2.3 Wire the agent to have access to the Neovim MCP server tools (read, write, command execution, file operations)

## 3. Create fixture setup script

- [ ] 3.1 Create `scripts/mcp-test-setup.sh` that accepts a fixture name, validates `$JAVA_HOME` and `java`, and compiles the fixture
- [ ] 3.2 Handle fixture-not-found errors with a list of available fixtures
- [ ] 3.3 Create `tests/fixtures/fixtures.json` registry mapping fixture names to paths and descriptions
- [ ] 3.4 Test the script with `maven-simple` fixture

## 4. Write manual test scenario files

- [ ] 4.1 Create `tests/manual-scenarios/` directory
- [ ] 4.2 Write `tests/manual-scenarios/test-discovery.md` — steps to verify `is_test_file` returns correct results for Java test and non-test files
- [ ] 4.3 Write `tests/manual-scenarios/test-execution.md` — steps to run tests and verify pass/fail results match expectations
- [ ] 4.4 Write `tests/manual-scenarios/parameterized-test.md` — steps to verify parameterized test discovery and execution
- [ ] 4.5 Write `tests/manual-scenarios/debug-test.md` — steps to verify nvim-dap debug command generation and breakpoint setting
- [ ] 4.6 Write `tests/manual-scenarios/multi-module.md` — steps to verify multi-module test discovery and execution (if fixture exists)

## 5. Documentation and final wiring

- [ ] 5.1 Add a `tests/manual-scenarios/README.md` explaining how to use the agent for manual testing
- [ ] 5.2 Verify all scenario files are loadable and the agent prompt references them correctly
- [ ] 5.3 Do a dry-run: ask the agent to run a test scenario and verify it follows the plan-act-report loop
- [ ] 5.4 Fix any issues found during the dry-run
