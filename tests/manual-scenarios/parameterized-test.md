# Scenario: Parameterized Tests

Verify that neotest-java correctly discovers and runs parameterized tests.

## Fixture

`maven-simple` — may need to add a parameterized test fixture if not present

## Steps

1. **Open a file with parameterized tests**
   - Open a test file that contains `@ParameterizedTest` annotations
   - If none exists in the fixture, note this limitation

2. **Discover test positions**
   - Run neotest's position discovery
   - Verify that parameterized tests are discovered as individual test positions
   - Each parameterized test should appear with its parameter values
     (if the test framework supports it)

3. **Run parameterized tests**
   - Execute the parameterized tests
   - Verify all parameter variations run

## Expected Results

- Parameterized tests are discovered and displayed as test positions
- Each parameter variation executes correctly
- Results are reported for each variation individually
- No interference with regular `@Test` methods in the same file
