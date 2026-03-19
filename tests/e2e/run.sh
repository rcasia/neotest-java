#!/bin/bash
# E2E test for neotest-java
# Runs real tests through Neotest and verifies results

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJ_ROOT=$(pwd)
FIXTURE_DIR="$PROJ_ROOT/tests/fixtures/maven-simple"
TEST_FILE="$FIXTURE_DIR/src/test/java/com/example/SampleTest.java"
MVNW="$FIXTURE_DIR/mvnw"

echo -e "${BLUE}=== Neotest-Java E2E Test ===${NC}\n"

# Check prerequisites
if [ ! -f "$MVNW" ]; then
    echo -e "${RED}✗ Maven wrapper not found at $MVNW${NC}"
    echo -e "${YELLOW}Please run: cd tests/fixtures/maven-simple && mvn wrapper:wrapper${NC}"
    exit 1
fi

if [ -z "$JAVA_HOME" ]; then
    echo -e "${RED}✗ JAVA_HOME not set${NC}"
    exit 1
fi

# Download JUnit Platform Console Standalone JAR if not present
JUNIT_VERSION="6.0.3"
JUNIT_JAR_NAME="junit-platform-console-standalone-${JUNIT_VERSION}.jar"
JUNIT_JAR_DIR="${HOME}/.local/share/nvim/neotest-java"
JUNIT_JAR_PATH="${JUNIT_JAR_DIR}/${JUNIT_JAR_NAME}"
JUNIT_URL="https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/${JUNIT_VERSION}/${JUNIT_JAR_NAME}"
JUNIT_SHA256="3ba0d6150af79214a1411f9ea2fbef864eef68b68c89a17f672c0b89bff9d3a2"

if [ ! -f "$JUNIT_JAR_PATH" ]; then
    echo -e "${YELLOW}Downloading JUnit Platform Console Standalone JAR...${NC}"
    mkdir -p "$JUNIT_JAR_DIR"

    if command -v curl &> /dev/null; then
        curl -fsSL -o "$JUNIT_JAR_PATH" "$JUNIT_URL"
    elif command -v wget &> /dev/null; then
        wget -q -O "$JUNIT_JAR_PATH" "$JUNIT_URL"
    else
        echo -e "${RED}✗ Neither curl nor wget found. Cannot download JUnit JAR.${NC}"
        exit 1
    fi

    # Verify checksum
    if command -v sha256sum &> /dev/null; then
        ACTUAL_SHA256=$(sha256sum "$JUNIT_JAR_PATH" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        ACTUAL_SHA256=$(shasum -a 256 "$JUNIT_JAR_PATH" | awk '{print $1}')
    else
        echo -e "${YELLOW}⚠ No checksum tool found. Skipping verification.${NC}"
        ACTUAL_SHA256="$JUNIT_SHA256"  # Skip verification
    fi

    if [ "$ACTUAL_SHA256" != "$JUNIT_SHA256" ]; then
        echo -e "${RED}✗ Checksum verification failed${NC}"
        echo "Expected: $JUNIT_SHA256"
        echo "Got:      $ACTUAL_SHA256"
        rm -f "$JUNIT_JAR_PATH"
        exit 1
    fi

    echo -e "${GREEN}✓ JUnit JAR downloaded and verified${NC}"
else
    echo -e "${GREEN}✓ JUnit JAR already present${NC}"
fi

# Compile test project and get classpath using Maven wrapper
echo -e "${YELLOW}Compiling test project...${NC}"
cd "$FIXTURE_DIR"
if "$MVNW" clean test-compile -q 2>&1; then
    echo -e "${GREEN}✓ Compiled${NC}"
else
    echo -e "${RED}✗ Compilation failed${NC}"
    echo "Maven wrapper: $MVNW"
    echo "Current directory: $(pwd)"
    echo "Trying with verbose output:"
    "$MVNW" clean test-compile || true
    exit 1
fi

echo -e "${YELLOW}Resolving classpath...${NC}"
if "$MVNW" dependency:build-classpath -Dmdep.outputFile=/tmp/maven-classpath.txt -q 2>&1; then
    echo -e "${GREEN}✓ Classpath resolved${NC}"
else
    echo -e "${RED}✗ Classpath resolution failed${NC}"
    "$MVNW" dependency:build-classpath -Dmdep.outputFile=/tmp/maven-classpath.txt || true
    exit 1
fi
cd "$PROJ_ROOT"

# Read Maven classpath and add target directories (use absolute paths)
MAVEN_CP=$(cat /tmp/maven-classpath.txt)
FULL_CP="$(cd "$FIXTURE_DIR" && pwd)/target/classes:$(cd "$FIXTURE_DIR" && pwd)/target/test-classes:$MAVEN_CP"

# Create Lua script to run tests via Neotest with mocked dependencies
cat > /tmp/neotest-e2e.lua << EOFSCRIPT
local test_file = vim.fn.argv()[1]
local classpath = vim.fn.argv()[2]

-- Install mocks for jdtls-dependent modules BEFORE loading neotest-java
require("tests.e2e.mocks").install_mocks(classpath)

-- Setup neotest
local neotest = require("neotest")
neotest.setup({
  adapters = {
    require("neotest-java")({
      ignore_wrapper = false,
    })
  },
})

-- Run tests asynchronously
vim.schedule(function()
  local nio = require("nio")
  nio.run(function()
    -- Call run - this will register the adapter and execute tests
    neotest.run.run(test_file)

    -- Wait for test execution to complete using status_counts
    local max_attempts = 40  -- 20 seconds (500ms * 40)
    local attempt = 0
    local counts = nil

    while attempt < max_attempts do
      nio.sleep(500)
      attempt = attempt + 1

      -- Get adapter IDs (should be populated after run())
      local adapter_ids = neotest.state.adapter_ids()
      if #adapter_ids == 0 then
        -- Adapter not registered yet, keep waiting
        goto continue
      end

      -- Get status counts from the registered adapter
      local adapter_id = adapter_ids[1]
      counts = neotest.state.status_counts(adapter_id)

      -- Check if tests have finished (no tests running)
      if counts and counts.running == 0 and counts.total > 0 then
        -- Tests are complete!
        break
      end

      ::continue::
    end

    if not counts or counts.total == 0 then
      local f = io.open("/tmp/neotest-e2e-error.txt", "w")
      if f then
        f:write("Timeout: No test results after " .. attempt .. " attempts\\n")
        f:close()
      end
      vim.schedule(function()
        vim.cmd("cquit 1")
      end)
      return
    end

    -- Write status counts as JSON for snapshot testing
    local f = io.open("/tmp/neotest-e2e-results.json", "w")
    if f then
      f:write(vim.fn.json_encode(counts))
      f:close()
    end

    vim.schedule(function()
      vim.cmd("quitall")
    end)
  end)
end)

-- Overall timeout (30 seconds)
vim.defer_fn(function()
  local f = io.open("/tmp/neotest-e2e-error.txt", "w")
  if f then
    f:write("Global timeout (30s) reached\\n")
    f:close()
  end
  vim.cmd("cquit! 1")
end, 30000)
EOFSCRIPT

# Run the E2E test
echo -e "${YELLOW}Running tests via Neotest...${NC}"
rm -f /tmp/neotest-e2e-results.json /tmp/neotest-e2e-error.txt

if nvim --headless --noplugin -u tests/testrc.vim \
    -c "luafile /tmp/neotest-e2e.lua" \
    "$TEST_FILE" "$FULL_CP" 2>&1 | tee /tmp/neotest-e2e.log; then

    if [ -f /tmp/neotest-e2e-error.txt ]; then
        echo -e "${RED}✗ Test execution failed${NC}"
        cat /tmp/neotest-e2e-error.txt
        cat /tmp/neotest-e2e.log
        exit 1
    fi

    if [ -f /tmp/neotest-e2e-results.json ]; then
        echo -e "${GREEN}✓ Tests executed${NC}"

        # Path to snapshot file
        SNAPSHOT_FILE="$PROJ_ROOT/tests/e2e/__snapshots__/maven-simple.json"

        # Check if snapshot exists
        if [ ! -f "$SNAPSHOT_FILE" ]; then
            echo -e "${YELLOW}⚠ Snapshot file not found. Creating new snapshot at:${NC}"
            echo -e "${YELLOW}  $SNAPSHOT_FILE${NC}"
            mkdir -p "$(dirname "$SNAPSHOT_FILE")"
            cp /tmp/neotest-e2e-results.json "$SNAPSHOT_FILE"
            echo -e "${GREEN}✓ Snapshot created${NC}"
            exit 0
        fi

        # Compare results with snapshot
        if command -v jq &> /dev/null; then
            # Use jq for pretty comparison
            ACTUAL=$(jq -S . /tmp/neotest-e2e-results.json)
            EXPECTED=$(jq -S . "$SNAPSHOT_FILE")

            if [ "$ACTUAL" == "$EXPECTED" ]; then
                echo -e "${GREEN}✓ E2E TEST PASSED - Results match snapshot${NC}"
            else
                echo -e "${RED}✗ Results don't match snapshot${NC}"
                echo -e "${YELLOW}Expected:${NC}"
                echo "$EXPECTED"
                echo -e "${YELLOW}Actual:${NC}"
                echo "$ACTUAL"
                echo -e "${YELLOW}Diff:${NC}"
                diff <(echo "$EXPECTED") <(echo "$ACTUAL") || true
                exit 1
            fi
        else
            # Fallback to basic comparison without jq
            if diff -w "$SNAPSHOT_FILE" /tmp/neotest-e2e-results.json > /dev/null 2>&1; then
                echo -e "${GREEN}✓ E2E TEST PASSED - Results match snapshot${NC}"
            else
                echo -e "${RED}✗ Results don't match snapshot${NC}"
                echo -e "${YELLOW}Expected:${NC}"
                cat "$SNAPSHOT_FILE"
                echo -e "${YELLOW}Actual:${NC}"
                cat /tmp/neotest-e2e-results.json
                echo -e "${YELLOW}Diff:${NC}"
                diff -u "$SNAPSHOT_FILE" /tmp/neotest-e2e-results.json || true
                exit 1
            fi
        fi
    else
        echo -e "${RED}✗ No results generated${NC}"
        cat /tmp/neotest-e2e.log
        exit 1
    fi
else
    echo -e "${RED}✗ Neovim exited with error${NC}"
    if [ -f /tmp/neotest-e2e-error.txt ]; then
        cat /tmp/neotest-e2e-error.txt
    fi
    cat /tmp/neotest-e2e.log
    exit 1
fi

# Cleanup
rm -f /tmp/neotest-e2e.lua /tmp/neotest-e2e-results.json /tmp/neotest-e2e-error.txt /tmp/neotest-e2e.log /tmp/maven-classpath.txt

echo -e "\n${GREEN}=== E2E Test Complete ===${NC}"
