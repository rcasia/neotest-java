local plugin = require("neotest-java")
local it = require("nio").tests.it -- async

describe("file_checker", function()
	it("should return true for test files", function()
		local test_files = {
			"src/test/java/neotest/NeotestTest.java",
			"src/test/java/neotest/RepositoryTests.java",
			"src/test/java/neotest/NeotestIT.java",
			"src/test/java/neotest/ProductAceptanceTests.java",
		}

		for _, file_path in ipairs(test_files) do
			assert.is_true(plugin.is_test_file(file_path))
		end
	end)

	it("should return false for a java non-test file", function()
		local non_test_files = {
			"src/test/java/neotest/Configuration.java",
			"src/test/java/neotest/TestRepository.java",
			"src/test/java/neotest/Neotest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_false(plugin.is_test_file(file_path))
		end
	end)

	it("should return false for every class inside main folder", function()
		local non_test_files = {
			"src/main/java/neotest/NeotestTest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_false(plugin.is_test_file(file_path))
		end
	end)
end)
