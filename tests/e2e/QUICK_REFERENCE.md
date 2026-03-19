# E2E Testing - Quick Reference

## File Structure

```
tests/
├── e2e/
│   ├── run.lua                  # Core E2E test runner
│   ├── run-all.sh               # Run all E2E tests
│   ├── update-snapshots.sh      # Regenerate all snapshots
│   ├── mocks.lua                # Mock jdtls dependencies
│   └── README.md                # Full documentation
└── fixtures/
    └── maven-simple/
        ├── pom.xml
        └── src/test/java/com/example/
            ├── SampleTest.java
            ├── SampleTest.snapshot.json      # ← Snapshot per file
            ├── CalculatorTest.java
            └── CalculatorTest.snapshot.json  # ← Snapshot per file
```

## Common Commands

### Run All E2E Tests
```bash
make test-e2e
# or
./tests/e2e/run-all.sh
```

### Regenerate All Snapshots
```bash
./tests/e2e/update-snapshots.sh maven-simple
```

### Run Single Test File
```bash
nvim -l tests/e2e/run.lua \
  --fixture maven-simple \
  --test-file tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java
```

### Update Single Snapshot
```bash
nvim -l tests/e2e/run.lua \
  --update-snapshots \
  --fixture maven-simple \
  --test-file tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java
```

## Workflow: Adding New Test Methods

1. **Edit existing test file** (e.g., add new `@Test` methods to `SampleTest.java`)
2. **Regenerate snapshot:**
   ```bash
   ./tests/e2e/update-snapshots.sh maven-simple
   ```
3. **Verify:**
   ```bash
   make test-e2e
   ```
4. **Commit:**
   ```bash
   git add tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java
   git add tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.snapshot.json
   git commit -m "test: add new test methods to SampleTest"
   ```

## Workflow: Adding New Test Files

1. **Create new test file:**
   ```bash
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

2. **Generate snapshot:**
   ```bash
   ./tests/e2e/update-snapshots.sh maven-simple
   ```
   This will create `tests/fixtures/maven-simple/src/test/java/com/example/MathTest.snapshot.json`

3. **Verify:**
   ```bash
   make test-e2e
   ```

4. **Commit:**
   ```bash
   git add tests/fixtures/maven-simple/src/test/java/com/example/MathTest.java
   git add tests/fixtures/maven-simple/src/test/java/com/example/MathTest.snapshot.json
   git commit -m "test: add MathTest fixture"
   ```

## Snapshot Format

Each test file has a corresponding `.snapshot.json` file that contains:

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

The snapshot captures:
- Test method names
- Full test IDs (used by neotest)
- Test type ("test")

The E2E test verifies that neotest discovers exactly these tests when running the corresponding test file.

## Key Features

- ✅ **Per-file snapshots** - Each test file has its own snapshot
- ✅ **Automatic snapshot generation** - Missing snapshots are created automatically
- ✅ **Filtered results** - Only tests from the target file are included in the snapshot
- ✅ **Easy maintenance** - Add test methods/files and regenerate snapshots with one command
- ✅ **CI-friendly** - Tests run in headless Neovim for automation
