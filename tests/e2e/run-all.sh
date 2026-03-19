#!/usr/bin/env bash
# Run all E2E tests
#
# Usage:
#   ./tests/e2e/run-all.sh                    # Run all tests in all fixtures
#   ./tests/e2e/run-all.sh maven-simple       # Run tests in specific fixture
#
# This script finds all test files in the fixtures and runs E2E tests for each.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="${1:-maven-simple}"

FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/$FIXTURE"

if [ ! -d "$FIXTURE_DIR" ]; then
    echo "Error: Fixture directory not found: $FIXTURE_DIR"
    exit 1
fi

echo "Running E2E tests for fixture: $FIXTURE"
echo ""

# Find all test files in the fixture
TEST_FILES=$(find "$FIXTURE_DIR/src/test/java" -name "*Test.java" 2>/dev/null || true)

if [ -z "$TEST_FILES" ]; then
    echo "No test files found in $FIXTURE_DIR/src/test/java"
    exit 1
fi

TOTAL=0
PASSED=0
FAILED=0

for test_file in $TEST_FILES; do
    TOTAL=$((TOTAL + 1))
    test_name=$(basename "$test_file" .java)

    echo "Running E2E test: $test_name"

    if nvim -l "$SCRIPT_DIR/run.lua" --fixture "$FIXTURE" --test-file "$test_file"; then
        PASSED=$((PASSED + 1))
        echo "✓ $test_name PASSED"
    else
        FAILED=$((FAILED + 1))
        echo "✗ $test_name FAILED"
    fi

    echo ""
done

echo "================================================"
echo "E2E Test Summary"
echo "================================================"
echo "Total test files: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "⚠ Some tests failed"
    exit 1
else
    echo "✓ All tests passed"
fi
