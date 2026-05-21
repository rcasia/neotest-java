---@diagnostic disable: undefined-field
-- E2E test: Groovy/Spock test discovery and execution
-- This test verifies that neotest-java correctly discovers and runs Groovy test files

local nio = require("nio")

describe("E2E: neotest-java Groovy/Spock support", function()
	local neotest
	local groovy_fixture_dir = vim.fn.getcwd() .. "/tests/fixtures/maven-groovy"
	local calculator_spec = groovy_fixture_dir .. "/src/test/groovy/com/example/CalculatorSpec.groovy"
	local user_service_test = groovy_fixture_dir .. "/src/test/groovy/com/example/UserServiceTest.groovy"

	before_each(function()
		package.loaded["neotest"] = nil
		package.loaded["neotest-java"] = nil

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

	it("discovers Groovy test files with .groovy extension", function()
		assert.is_true(vim.fn.filereadable(calculator_spec) == 1, "CalculatorSpec.groovy should exist")
		assert.is_true(vim.fn.filereadable(user_service_test) == 1, "UserServiceTest.groovy should exist")

		nio.run(function()
			neotest.run.run(calculator_spec)

			local max_wait = 30000
			local start_time = vim.uv.now()
			local results = nil

			while vim.uv.now() - start_time < max_wait do
				nio.sleep(500)
				results = neotest.state.results()
				if results and next(results) ~= nil then
					break
				end
			end

			assert.is_not_nil(results, "Should have test results for CalculatorSpec.groovy")
			assert.is_true(next(results) ~= nil, "Results should not be empty")

			local test_count = 0
			for test_id, _ in pairs(results) do
				if test_id:match("Spec") or test_id:match("Test") then
					test_count = test_count + 1
				end
			end

			assert.is_true(test_count >= 4, "Should discover at least 4 tests from CalculatorSpec, got " .. test_count)

			print(string.format("\n✓ Groovy discovery: %d tests found in CalculatorSpec.groovy", test_count))
		end)
	end)

	it("runs Groovy JUnit tests and reports pass/fail results", function()
		nio.run(function()
			neotest.run.run(user_service_test)

			local max_wait = 30000
			local start_time = vim.uv.now()
			local results = nil

			while vim.uv.now() - start_time < max_wait do
				nio.sleep(500)
				results = neotest.state.results()
				if results and next(results) ~= nil then
					break
				end
			end

			assert.is_not_nil(results, "Should have test results for UserServiceTest.groovy")

			local passed = 0
			local failed = 0
			local total = 0

			for test_id, result in pairs(results) do
				if test_id:match("Test") then
					total = total + 1
					if result.status == "passed" then
						passed = passed + 1
					elseif result.status == "failed" then
						failed = failed + 1
					end
				end
			end

			assert.is_true(total >= 4, "Should have at least 4 test results, got " .. total)
			assert.is_true(passed >= 3, "Should have at least 3 passing tests, got " .. passed)
			assert.is_true(failed >= 1, "Should have at least 1 failing test, got " .. failed)

			print(string.format("\n✓ Groovy JUnit Results: %d total, %d passed, %d failed", total, passed, failed))
		end)
	end)

	it("discovers both Java and Groovy tests in mixed projects", function()
		nio.run(function()
			neotest.run.run(groovy_fixture_dir)

			local max_wait = 30000
			local start_time = vim.uv.now()
			local results = nil

			while vim.uv.now() - start_time < max_wait do
				nio.sleep(500)
				results = neotest.state.results()
				if results and next(results) ~= nil then
					break
				end
			end

			assert.is_not_nil(results, "Should have test results")

			local groovy_tests = 0
			local java_tests = 0

			for test_id, _ in pairs(results) do
				if test_id:match("%.groovy") or test_id:match("Spec") then
					groovy_tests = groovy_tests + 1
				elseif test_id:match("%.java") or test_id:match("Test") then
					java_tests = java_tests + 1
				end
			end

			assert.is_true(groovy_tests > 0, "Should discover Groovy tests")
			assert.is_true(java_tests > 0, "Should discover Java tests")

			print(string.format("\n✓ Mixed project: %d Groovy tests, %d Java tests", groovy_tests, java_tests))
		end)
	end)
end)
