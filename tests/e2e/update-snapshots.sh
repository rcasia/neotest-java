#!/usr/bin/env bash
# Update all E2E test snapshots
#
# Usage:
#   ./tests/e2e/update-snapshots.sh                    # Update all snapshots
#   ./tests/e2e/update-snapshots.sh maven-simple       # Update specific fixture
#
# This script finds all test files in the fixtures and regenerates their snapshots.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="${1:-maven-simple}"

FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/$FIXTURE"

if [ ! -d "$FIXTURE_DIR" ]; then
    echo "Error: Fixture directory not found: $FIXTURE_DIR"
    exit 1
fi

echo "Updating snapshots for fixture: $FIXTURE"
echo ""

# Find all test files in the fixture
TEST_FILES=$(find "$FIXTURE_DIR/src/test/java" -name "*Test.java" 2>/dev/null || true)

if [ -z "$TEST_FILES" ]; then
    echo "No test files found in $FIXTURE_DIR/src/test/java"
    exit 1
fi

TOTAL=0
SUCCESS=0
FAILED=0

for test_file in $TEST_FILES; do
    TOTAL=$((TOTAL + 1))
    test_name=$(basename "$test_file" .java)

    echo "Updating snapshot for: $test_name"

    if nvim -l "$SCRIPT_DIR/run.lua" --update-snapshots --fixture "$FIXTURE" --test-file "$test_file"; then
        SUCCESS=$((SUCCESS + 1))
        echo "✓ $test_name snapshot updated"
    else
        FAILED=$((FAILED + 1))
        echo "✗ $test_name snapshot update failed"
    fi

    echo ""
done

echo "================================================"
echo "Snapshot Update Summary"
echo "================================================"
echo "Total test files: $TOTAL"
echo "Successfully updated: $SUCCESS"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "⚠ Some snapshots failed to update"
    exit 1
else
    echo "✓ All snapshots updated successfully"
fi
