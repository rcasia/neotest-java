-- E2E test: Groovy/Spock test file detection
-- This test verifies that neotest-java correctly detects Groovy/Spock test files

local nio = require("nio")

describe("E2E: Groovy/Spock test file detection", function()
	local neotest
	local java = require("neotest-java")
	local Path = require("neotest-java.model.path")

	local groovy_project_dir = vim.fn.getcwd() .. "/tests/fixtures/maven-groovy"

	local spec_file = groovy_project_dir .. "/src/test/groovy/com/example/CalculatorSpec.groovy"
	local test_file = groovy_project_dir .. "/src/test/groovy/com/example/UserServiceTest.groovy"
	local main_file = groovy_project_dir .. "/src/main/groovy/com/example/Calculator.groovy"

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

	it("detects Groovy Spec files as test files", function()
		-- Make sure test file exists
		assert.is_true(vim.fn.filereadable(spec_file) == 1, "Spec file should exist: " .. spec_file)

		-- Test file detection through the adapter
		local adapter = java()
		local is_test = adapter.is_test_file(spec_file)

		assert.is_true(is_test, "CalculatorSpec.groovy should be detected as a test file")
	end)

	it("detects Groovy Test files as test files", function()
		-- Make sure test file exists
		assert.is_true(vim.fn.filereadable(test_file) == 1, "Test file should exist: " .. test_file)

		-- Test file detection through the adapter
		local adapter = java()
		local is_test = adapter.is_test_file(test_file)

		assert.is_true(is_test, "UserServiceTest.groovy should be detected as a test file")
	end)

	it("does not detect main Groovy files as test files", function()
		-- Make sure file exists
		assert.is_true(vim.fn.filereadable(main_file) == 1, "Main file should exist: " .. main_file)

		-- Test file detection through the adapter
		local adapter = java()
		local is_test = adapter.is_test_file(main_file)

		assert.is_false(is_test, "Calculator.groovy (in src/main) should not be detected as a test file")
	end)

	it("finds Groovy test files during directory scan", function()
		nio.run(function()
			local adapter = java()

			-- Scan the test directory
			local test_dir = Path(groovy_project_dir):append("src"):append("test")
			local files = adapter.discover_positions(test_dir:to_string())

			-- Should find at least the test files
			assert.is_not_nil(files, "Should discover positions in test directory")

			-- Convert tree to table to check contents
			local found_files = {}
			for node in files:iter() do
				if node.type == "file" then
					table.insert(found_files, node.path)
				end
			end

			-- Should have found the test files
			local found_spec = false
			local found_test = false
			for _, path in ipairs(found_files) do
				if path:match("CalculatorSpec%.groovy$") then
					found_spec = true
				end
				if path:match("UserServiceTest%.groovy$") then
					found_test = true
				end
			end

			assert.is_true(found_spec, "Should find CalculatorSpec.groovy")
			assert.is_true(found_test, "Should find UserServiceTest.groovy")
		end)
	end)

	it("finds the Groovy project root", function()
		local adapter = java()
		local root = adapter.root(groovy_project_dir)

		assert.is_not_nil(root, "Should find project root")
		assert.is_true(root:match("maven%-groovy$") ~= nil, "Root should be the maven-groovy directory: " .. root)
	end)
end)
