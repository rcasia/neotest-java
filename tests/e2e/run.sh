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

# Compile test project and get classpath using Maven wrapper
echo -e "${YELLOW}Compiling test project...${NC}"
cd "$FIXTURE_DIR"
if "$MVNW" clean test-compile -q; then
    echo -e "${GREEN}✓ Compiled${NC}"
else
    echo -e "${RED}✗ Compilation failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Resolving classpath...${NC}"
if "$MVNW" dependency:build-classpath -Dmdep.outputFile=/tmp/maven-classpath.txt -q; then
    echo -e "${GREEN}✓ Classpath resolved${NC}"
else
    echo -e "${RED}✗ Classpath resolution failed${NC}"
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
    local max_attempts = 60  -- 30 seconds
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

    -- Write results using status counts
    local f = io.open("/tmp/neotest-e2e-results.txt", "w")
    if f then
      f:write(string.format("%d,%d,%d\\n", counts.total, counts.passed, counts.failed))
      -- Also write full counts for debug
      f:write(string.format("Status counts: %s\\n", vim.inspect(counts)))
      f:close()
    end

    vim.schedule(function()
      vim.cmd("quitall")
    end)
  end)
end)

-- Overall timeout
vim.defer_fn(function()
  local f = io.open("/tmp/neotest-e2e-error.txt", "w")
  if f then
    f:write("Global timeout (60s) reached\\n")
    f:close()
  end
  vim.cmd("cquit! 1")
end, 60000)
EOFSCRIPT

# Run the E2E test
echo -e "${YELLOW}Running tests via Neotest...${NC}"
rm -f /tmp/neotest-e2e-results.txt /tmp/neotest-e2e-error.txt

if nvim --headless --noplugin -u tests/testrc.vim \
    -c "luafile /tmp/neotest-e2e.lua" \
    "$TEST_FILE" "$FULL_CP" 2>&1 | tee /tmp/neotest-e2e.log; then

    if [ -f /tmp/neotest-e2e-error.txt ]; then
        echo -e "${RED}✗ Test execution failed${NC}"
        cat /tmp/neotest-e2e-error.txt
        cat /tmp/neotest-e2e.log
        exit 1
    fi

    if [ -f /tmp/neotest-e2e-results.txt ]; then
        IFS=',' read -r total passed failed < /tmp/neotest-e2e-results.txt
        echo -e "${GREEN}✓ Tests executed${NC}"
        echo -e "${BLUE}Results: $total total, $passed passed, $failed failed${NC}"

        if [ "$total" -eq 4 ] && [ "$passed" -eq 2 ] && [ "$failed" -eq 2 ]; then
            echo -e "${GREEN}✓ E2E TEST PASSED - Got expected 4 tests (2 pass, 2 fail)${NC}"
        else
            echo -e "${RED}✗ Unexpected results (expected: 4 total, 2 passed, 2 failed)${NC}"
            echo "Full results:"
            cat /tmp/neotest-e2e-results.txt
            exit 1
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
rm -f /tmp/neotest-e2e.lua /tmp/neotest-e2e-results.txt /tmp/neotest-e2e-error.txt /tmp/neotest-e2e.log /tmp/maven-classpath.txt

echo -e "\n${GREEN}=== E2E Test Complete ===${NC}"
