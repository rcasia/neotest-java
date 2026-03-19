# End-to-End (E2E) Tests

This directory contains end-to-end tests for neotest-java that validate the complete workflow from running tests to receiving results.

## What the E2E Test Validates

The E2E test validates the **full user workflow**:

1. ✅ **Test Discovery**: Adapter recognizes Java test files
2. ✅ **Test Compilation**: Tests are compiled (via Maven in this case)
3. ✅ **Test Execution**: Tests run through neotest's `run.run()` API
4. ✅ **Result Parsing**: Pass/fail results are correctly captured
5. ✅ **Status Reporting**: Results are accessible via `neotest.state`

This validates that neotest-java works correctly in a **headless Neovim environment**, making it suitable for CI/CD pipelines.

## Prerequisites

Before running E2E tests, ensure you have:

- **Java JDK** installed (Java 11 or higher)
- **JAVA_HOME** environment variable set
- **Neovim** (nvim) installed

**Note:** Maven is **not required** to be installed globally. The test fixture includes a Maven wrapper (`mvnw`) that will be used automatically.

### Check Prerequisites

```bash
# Check Java
java -version

# Check JAVA_HOME
echo $JAVA_HOME

# Check Neovim
nvim --version
```

## Running the E2E Tests

### Run All E2E Tests

```bash
# From the project root
make test-e2e

# Or directly
./tests/e2e/run-all.sh
```

This will run E2E tests for all test files in the fixture and compare results against their snapshots.

### Run a Specific Test File

```bash
nvim -l tests/e2e/run.lua \
  --fixture maven-simple \
  --test-file tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java
```

## Managing Snapshots

### Snapshot Testing

Each test file has its own snapshot that captures the expected test structure:

```
tests/fixtures/maven-simple/src/test/java/com/example/
├── SampleTest.java
├── SampleTest.snapshot.json          # Snapshot for SampleTest
├── CalculatorTest.java
└── CalculatorTest.snapshot.json      # Snapshot for CalculatorTest
```

**Snapshot Format:**
```json
{
  "results": {
    "testMethodName": {
      "id": "com.example.ClassName#testMethodName()",
      "name": "testMethodName",
      "type": "test"
    }
  }
}
```

### Update All Snapshots

When you add new test methods or test files, regenerate snapshots:

```bash
# Update all snapshots in a fixture
./tests/e2e/update-snapshots.sh maven-simple
```

### Update a Single Snapshot

```bash
nvim -l tests/e2e/run.lua \
  --update-snapshots \
  --fixture maven-simple \
  --test-file tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java
```

### Workflow for Adding New Tests

1. **Add new test methods** or **create new test files** in your fixture:
   ```bash
   # Example: Add a new test file
   cat > tests/fixtures/maven-simple/src/test/java/com/example/MathTest.java <<'EOF'
   package com.example;

   import org.junit.jupiter.api.Test;
   import static org.junit.jupiter.api.Assertions.*;

   public class MathTest {
       @Test
       public void testAddition() {
           assertEquals(4, 2 + 2);
       }
   }
   EOF
   ```

2. **Generate snapshots** for all test files:
   ```bash
   ./tests/e2e/update-snapshots.sh maven-simple
   ```

3. **Run E2E tests** to verify:
   ```bash
   make test-e2e
   ```

4. **Commit the changes**:
   ```bash
   git add tests/fixtures/maven-simple/src/test/java/com/example/MathTest.java
   git add tests/fixtures/maven-simple/src/test/java/com/example/MathTest.snapshot.json
   git commit -m "test: add MathTest fixture"
   ```

## Test Structure

### Test Fixture

The test uses a Maven-based fixture located at:
```
tests/fixtures/maven-simple/
├── pom.xml
└── src/test/java/com/example/
    ├── SampleTest.java           # 4 tests (2 pass, 2 fail)
    ├── SampleTest.snapshot.json
    ├── CalculatorTest.java       # 4 tests (all pass)
    └── CalculatorTest.snapshot.json
```

### How It Works

1. **Compilation Phase**:
   - Uses the Maven wrapper (`mvnw`) included in the test fixture
   - Runs `./mvnw clean test-compile` to compile test classes
   - Runs `./mvnw dependency:build-classpath` to get Maven dependencies

2. **Execution Phase**:
   - Launches Neovim in headless mode
   - Loads neotest with the Java adapter
   - Mocks jdtls dependencies (binaries, classpath, compiler)
   - Calls `neotest.run.run()` to execute tests
   - Filters results to only include tests from the target file

3. **Validation Phase**:
   - Compares results against the test file's snapshot
   - Verifies test IDs and names match expected values

### Mocked Dependencies

Since jdtls (Java Language Server) doesn't run in headless mode, the E2E test mocks three components:

1. **Binaries Module**: Returns system Java from `$JAVA_HOME`
2. **Classpath Provider**: Returns Maven-resolved classpath
3. **LSP Compiler**: No-op (tests are pre-compiled by Maven)

This approach validates that neotest-java works correctly when integrated with real build tools like Maven.

## Expected Output

When successful, you'll see:

```
=== Neotest-Java E2E Test ===

✓ JUnit JAR already present
Compiling test project...
✓ Compiled
Resolving classpath...
✓ Classpath resolved
Running tests via Neotest...
✓ Tests executed
✓ E2E TEST PASSED - Results match snapshot

=== E2E Test Complete ===
```

## Troubleshooting

### "Maven wrapper not found"

The Maven wrapper should be included in the test fixture. If it's missing, generate it:

```bash
cd tests/fixtures/maven-simple
mvn wrapper:wrapper  # Requires Maven to be installed temporarily
cd ../../..
```

Or restore it from git if it was accidentally deleted:
```bash
git checkout tests/fixtures/maven-simple/mvnw tests/fixtures/maven-simple/.mvn/
```

### "JAVA_HOME not set"

Set JAVA_HOME environment variable:
```bash
# Find your Java installation
which java
/usr/libexec/java_home  # On macOS

# Set JAVA_HOME (add to ~/.bashrc or ~/.zshrc)
export JAVA_HOME=/path/to/your/java
```

### "Compilation failed"

Ensure Java version is compatible:
```bash
java -version  # Should be 11 or higher
```

### Test hangs or times out

- Check that `$JAVA_HOME/bin/java` is executable
- Verify the test fixture compiles: `cd tests/fixtures/maven-simple && ./mvnw clean test-compile`
- Check logs in `/tmp/neotest-e2e.log` (if test fails)

## Why Run E2E Tests?

Unlike unit tests that mock components, E2E tests validate:

- ✅ **Real integration** with build tools (Maven/Gradle)
- ✅ **Actual JUnit execution** via junit-platform-console-standalone
- ✅ **Complete async workflow** in Neovim
- ✅ **Result parsing** from real JUnit XML reports
- ✅ **Compatibility** with headless environments (CI/CD)

E2E tests catch issues that unit tests miss, such as:
- Classpath resolution problems
- JUnit version incompatibilities
- Async timing issues
- XML parsing errors

## CI/CD Integration

The E2E test is designed to run in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run E2E Tests
  run: |
    export JAVA_HOME=$JAVA_HOME_11_X64
    ./tests/e2e/run.sh
```

The test runs in headless Neovim and exits with:
- Exit code **0** if tests pass
- Exit code **1** if tests fail or error

## Limitations

The current E2E test:

- Only tests Maven projects (Gradle support could be added)
- Only tests JUnit 5 (JUnit 4 support exists in the adapter)
- Uses snapshot testing for status counts and test IDs (not test output/diagnostics)
- Requires jdtls mocking (doesn't test with real LSP)

Future improvements could add:
- Gradle fixture
- JUnit 4 fixture  
- Spring Boot application tests
- Multi-module Maven project tests
- Test output and diagnostic snapshots
