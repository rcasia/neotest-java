#!/usr/bin/env bash
# Run all E2E tests
#
# Usage:
#   ./tests/e2e/run-all.sh                    # Run all fixtures
#   ./tests/e2e/run-all.sh maven-simple       # Run specific fixture
#
# This script finds all fixtures and runs E2E tests for each.
# Supports both Java (.java) and Groovy (.groovy) test files.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"

run_fixture() {
    local FIXTURE="$1"
    local FIXTURE_DIR="$FIXTURES_DIR/$FIXTURE"

    if [ ! -d "$FIXTURE_DIR" ]; then
        echo "Error: Fixture directory not found: $FIXTURE_DIR"
        return 1
    fi

    echo "Running E2E tests for fixture: $FIXTURE"
    echo ""

    # Find Java and Groovy test files
    local TEST_FILES=""
    if [ -d "$FIXTURE_DIR/src/test/java" ]; then
        TEST_FILES=$(find "$FIXTURE_DIR/src/test/java" -name "*Test.java" -o -name "*Spec.java" -o -name "*IT.java" 2>/dev/null || true)
    fi
    if [ -d "$FIXTURE_DIR/src/test/groovy" ]; then
        local GROOVY_FILES=$(find "$FIXTURE_DIR/src/test/groovy" -name "*Test.groovy" -o -name "*Spec.groovy" -o -name "*IT.groovy" 2>/dev/null || true)
        if [ -n "$GROOVY_FILES" ]; then
            if [ -n "$TEST_FILES" ]; then
                TEST_FILES="$TEST_FILES"$'\n'"$GROOVY_FILES"
            else
                TEST_FILES="$GROOVY_FILES"
            fi
        fi
    fi

    if [ -z "$TEST_FILES" ]; then
        echo "No test files found in $FIXTURE_DIR"
        return 1
    fi

    local TOTAL=0
    local PASSED=0
    local FAILED=0

    while IFS= read -r test_file; do
        [ -z "$test_file" ] && continue
        TOTAL=$((TOTAL + 1))
        test_name=$(basename "$test_file")

        echo "Running E2E test: $test_name"

        if nvim -l "$SCRIPT_DIR/run.lua" --fixture "$FIXTURE" --test-file "$test_file"; then
            PASSED=$((PASSED + 1))
            echo "✓ $test_name PASSED"
        else
            FAILED=$((FAILED + 1))
            echo "✗ $test_name FAILED"
        fi

        echo ""
    done <<< "$TEST_FILES"

    echo "------------------------------------------------"
    echo "Fixture: $FIXTURE - Total: $TOTAL, Passed: $PASSED, Failed: $FAILED"
    echo ""

    if [ $FAILED -gt 0 ]; then
        return 1
    fi
    return 0
}

# Determine which fixtures to run
if [ -n "$1" ]; then
    run_fixture "$1"
else
    echo "Discovering fixtures in $FIXTURES_DIR"
    echo ""

    GRAND_TOTAL=0
    GRAND_PASSED=0
    GRAND_FAILED=0

    for fixture_dir in "$FIXTURES_DIR"/*/; do
        [ ! -d "$fixture_dir" ] && continue
        fixture_name=$(basename "$fixture_dir")

        if run_fixture "$fixture_name"; then
            GRAND_PASSED=$((GRAND_PASSED + 1))
        else
            GRAND_FAILED=$((GRAND_FAILED + 1))
        fi
        GRAND_TOTAL=$((GRAND_TOTAL + 1))
    done

    echo "================================================"
    echo "E2E Test Summary"
    echo "================================================"
    echo "Total fixtures: $GRAND_TOTAL"
    echo "Passed: $GRAND_PASSED"
    echo "Failed: $GRAND_FAILED"
    echo ""

    if [ $GRAND_FAILED -gt 0 ]; then
        echo "⚠ Some fixtures failed"
        exit 1
    else
        echo "✓ All fixtures passed"
    fi
fi
