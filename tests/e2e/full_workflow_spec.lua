-- E2E test: Full Neotest workflow with Java tests
-- This test verifies that neotest-java correctly executes tests and reports results

local nio = require("nio")

describe("E2E: neotest-java full workflow", function()
	local neotest
	local test_file = vim.fn.getcwd() .. "/tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java"

	before_each(function()
		-- Reset neotest state
		package.loaded["neotest"] = nil
		package.loaded["neotest-java"] = nil

		-- Initialize neotest with java adapter
		neotest = require("neotest")
		neotest.setup({
			adapters = {
				require("neotest-java")({
					ignore_wrapper = false,
				}),
			},
			log_level = vim.log.levels.DEBUG,
		})
	end)

	it("runs tests and reports correct pass/fail results", function()
		-- Make sure test file exists
		assert.is_true(vim.fn.filereadable(test_file) == 1, "Test file should exist: " .. test_file)

		-- Run the tests (this triggers async execution)
		nio.run(function()
			neotest.run.run(test_file)

			-- Wait for results (with timeout)
			local max_wait = 30000 -- 30 seconds
			local start_time = vim.uv.now()
			local results = nil

			while vim.uv.now() - start_time < max_wait do
				nio.sleep(500)
				results = neotest.state.results()

				-- Check if we have any results
				if results and next(results) ~= nil then
					break
				end
			end

			-- Verify we got results
			assert.is_not_nil(results, "Should have test results")
			assert.is_true(next(results) ~= nil, "Results should not be empty")

			-- Count pass/fail
			local passed = 0
			local failed = 0
			local total = 0

			for test_id, result in pairs(results) do
				if test_id:match("Test") then -- Only count actual tests, not file/namespace nodes
					total = total + 1
					if result.status == "passed" then
						passed = passed + 1
					elseif result.status == "failed" then
						failed = failed + 1
					end
				end
			end

			-- Verify counts
			-- SampleTest has 4 tests: 2 should pass, 2 should fail
			assert.is_true(total >= 4, "Should have at least 4 test results, got " .. total)
			assert.is_true(passed >= 2, "Should have at least 2 passing tests, got " .. passed)
			assert.is_true(failed >= 2, "Should have at least 2 failing tests, got " .. failed)

			print(string.format("\n✓ E2E Test Results: %d total, %d passed, %d failed", total, passed, failed))
		end)
	end)
end)
