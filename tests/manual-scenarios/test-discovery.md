# Scenario: Test Discovery

Verify that neotest-java correctly discovers Java test files.

## Fixture

`maven-simple` — Single-module Maven project with JUnit 5 tests

## Steps

1. **Open a test file**
   - Open `tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java`
     in Neovim
   - Verify the file opens without errors

2. **Check is_test_file returns true**
   - Run neotest's check to see if Neovim identifies this as a test file
   - Expected: neotest-java's `is_test_file` returns `true` for `SampleTest.java`

3. **Open a non-test file**
   - Open `tests/fixtures/maven-simple/src/main/java/com/example/App.java`
   - Verify the file opens without errors

4. **Check is_test_file returns false**
   - Run neotest's check to see if Neovim identifies this as a test file
   - Expected: neotest-java's `is_test_file` returns `false` for a non-test file

## Expected Results

- Test files (`*Test.java`, `*Tests.java`, `*Spec.java`, `*IT.java`)
  are correctly identified
- Non-test files are not identified as tests
- No crashes or errors during file opening
