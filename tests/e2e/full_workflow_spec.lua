-- E2E test: Full Neotest workflow with Java tests
local nio = require("nio")

describe("E2E: neotest-java full workflow", function()
	local neotest
	local test_file = vim.fn.getcwd() .. "/tests/fixtures/maven-simple/src/test/java/com/example/SampleTest.java"

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

	it("runs tests and reports correct pass/fail results", function()
		MiniTest.expect.no_error(function()
			assert(vim.fn.filereadable(test_file) == 1, "Test file should exist: " .. test_file)
		end)

		nio.run(function()
			neotest.run.run(test_file)

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

			MiniTest.expect.no_error(function()
				assert(results ~= nil, "Should have test results")
				assert(next(results) ~= nil, "Results should not be empty")
			end)

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

			MiniTest.expect.no_error(function()
				assert(total >= 4, "Should have at least 4 test results, got " .. total)
				assert(passed >= 2, "Should have at least 2 passing tests, got " .. passed)
				assert(failed >= 2, "Should have at least 2 failing tests, got " .. failed)
			end)
		end)
	end)
end)
