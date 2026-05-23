# Scenario: Debug Test

Verify that neotest-java generates correct debug commands and integrates with nvim-dap.

## Fixture

`maven-simple` — Single-module Maven project

## Prerequisites

- nvim-dap must be configured in the container's Neovim config
- This scenario validates debug command generation, not actual debugging
  (requires a running DAP server)

## Steps

1. **Open a test file**
   - Open `tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java`

2. **Discover test positions**
   - Run neotest's position discovery
   - Verify positions are found

3. **Check debug command generation**
   - Trigger a debug test run (e.g., via neotest's `run.run()` with debug strategy)
   - Capture the generated command or DAP configuration
   - Verify it includes JDWP arguments (`-agentlib:jdwp`) or correct DAP setup

4. **Verify DAP integration**
   - Check that neotest-java provides the correct `debug` adapter configuration
   - Verify breakpoints can be set on test methods

## Expected Results

- Debug command includes JDWP agent configuration
- DAP adapter configuration is valid
- nvim-dap recognizes the configuration
- Breakpoints can be placed on test lines (syntax permitting)
