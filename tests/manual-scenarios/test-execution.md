# Scenario: Test Execution

Verify that neotest-java correctly runs tests and reports pass/fail results.

## Fixture

`maven-simple` — Single-module Maven project with JUnit 5 tests
(some pass, some fail)

## Steps

1. **Open the test file**
   - Open `tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java`
   - This file contains known passing and failing tests

2. **Discover test positions**
   - Run neotest's position discovery within the file
   - Verify all test methods are discovered (you should see individual test positions)

3. **Run all tests in the file**
   - Execute `neotest.run.run()` on the file
   - Wait for the test run to complete
   - Capture the results

4. **Verify results**
   - Expected: the output shows which tests passed and which failed
   - Verify the test count matches expectations (e.g., 2 pass, 2 fail)
   - Check that failing tests include error messages

5. **Run a single test**
   - Position the cursor on a specific test method
   - Run `neotest.run.run()` on just that method
   - Verify only that single test executes

## Expected Results

- All test methods are discovered
- Tests execute and complete within a reasonable time
- Pass/fail status is correctly reported for each test
- Individual test execution works correctly
- Error messages are present for failing tests
