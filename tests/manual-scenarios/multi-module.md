# Scenario: Multi-Module Project

Verify that neotest-java correctly handles multi-module projects.

## Fixture

A multi-module Maven or Gradle project fixture is required. If none exists,
this scenario documents the expected behavior for when such a fixture is added.

## Steps

1. **Open the multi-module project**
   - Open a test file from a submodule (e.g., `module-a/...`)
   - Verify the project root is correctly identified
     (the parent project, not the submodule)

2. **Discover test positions in a submodule**
   - Run neotest's position discovery on a test file in a submodule
   - Verify test positions are found correctly

3. **Run tests in a submodule**
   - Execute tests in a submodule
   - Verify that classpaths are resolved correctly (including inter-module dependencies)

4. **Run tests across modules**
   - If supported by the project structure, run all tests across all modules
   - Verify results are reported per-module

## Expected Results

- Project root is correctly detected as the parent multi-module project
- Test positions are discovered in submodule test files
- Tests execute using the correct classpath for each submodule
- Results are clearly associated with their respective submodules
