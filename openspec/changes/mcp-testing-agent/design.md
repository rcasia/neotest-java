## Context

OpenCode supports custom subagents and MCP servers via `opencode.json`. The Neovim MCP server (already available in the OpenCode ecosystem) exposes Neovim's buffer editing, command execution, file operations, and search capabilities as MCP tools. By wiring these together, we can create a dedicated testing agent that opens Neovim, loads neotest-java with a test project fixture, runs tests, and reports results — all through conversation.

Currently, neotest-java has:

- Unit tests (busted/plenary) in `tests/unit/`
- E2E tests (headless Neovim + Maven) in `tests/e2e/`
- Test fixtures in `tests/fixtures/` (e.g., `maven-simple`)
- A `.opencode/opencode.json` config file with no MCP or subagent configuration

## Goals / Non-Goals

**Goals:**

- Configure the Neovim MCP server in `opencode.json` so OpenCode can interact with Neovim
- Define a `neotest-java-tester` subagent with a prompt that drives manual testing via MCP
- Create a library of manual test scenarios with step-by-step agent instructions
- Organize existing fixtures so the agent can quickly set up the right project type
- Provide a setup script (`scripts/mcp-test-setup.sh`) to prepare the environment

**Non-Goals:**

- Not replacing existing unit or E2E tests
- Not modifying neotest-java source code (only OpenCode config and test infrastructure)
- Not adding new test fixtures unless necessary for scenarios not covered by existing ones
- Not automating CI integration of the agent (future concern)

## Decisions

**1. Use the existing Neovim MCP server rather than building a custom one**

- The OpenCode ecosystem already provides a Neovim MCP server with tools for buffer editing, command execution, search, etc.
- Rationale: Zero additional server code. The server is battle-tested and maintained.
- Alternative considered: Building a custom testing MCP server. Rejected — would duplicate effort and add maintenance burden.

**2. Agent lives as an OpenCode subagent in `opencode.json` under `agent` config**

- OpenCode supports named subagents with custom prompts and tool access.
- Rationale: Keeps configuration co-located with the project's OpenCode setup. No separate files needed beyond what opencode.json supports.
- Alternative considered: Using a standalone script. Rejected — would lose the conversational interaction model.

**3. Test scenarios defined as markdown files that the agent reads as context**

- The agent prompt will instruct it to load scenario files from a known directory.
- Rationale: Scenarios are easy to write, version-control, and extend without changing agent configuration.
- Alternative considered: Hard-coding scenarios in the agent prompt. Rejected — would make the prompt bloated and harder to maintain.

**4. Fixture setup via a shell script rather than agent-driven Maven commands**

- A `scripts/mcp-test-setup.sh` script accepts a fixture name and prepares it (compiles, resolves classpath).
- Rationale: Faster and more reliable than driving Maven through Neovim shell commands. The agent invokes the script once.
- Alternative considered: Agent runs Maven commands inside Neovim. Rejected — slower, more error-prone, harder to debug.

**5. Agent prompt uses a "plan-act-report" loop pattern**

- The agent plans which test to run, acts by driving Neovim via MCP, then reports results back to the user.
- Rationale: Provides a structured, predictable workflow that is easy to follow and debug.
- Alternative considered: Free-form interaction. Rejected — too ambiguous for consistent results.

## Risks / Trade-offs

- **Neovim MCP server dependency**: The agent cannot function without the Neovim MCP server running → Mitigation: Document prerequisites clearly; the agent checks if the server is available before proceeding.
- **Fixture environment drift**: Test fixtures may become stale or require specific JDK versions → Mitigation: `mcp-test-setup.sh` validates prerequisites and reports clear errors.
- **Agent prompt complexity**: The agent needs detailed instructions without being overly rigid → Mitigation: Use modular scenario files instead of inlining everything in the prompt.
- **Session isolation**: Multiple testing sessions could interfere with each other → Mitigation: Each scenario runs in a clean Neovim instance; the setup script handles teardown.
