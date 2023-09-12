local plugin = require("neotest-java")

describe("file_checker", function()
	it("should return true for unit test files", function()
		local test_files = {
			"src/test/java/neotest/NeotestTest.java",
			"src/test/java/neotest/RepositoryTest.java",
		}

		for _, file_path in ipairs(test_files) do
			assert.is.True(plugin.is_test_file(file_path))
		end
	end)

	it("should return true for integration test files", function()
		local test_files = {
			"src/test/java/neotest/NeotestIT.java",
			"src/test/java/neotest/RepositoryIT.java",
			"src/test/java/neotest/RepositoryIntegrationTest.java",
			"src/test/java/neotest/RepositoryIntegrationTests.java",
		}

		for _, file_path in ipairs(test_files) do
			assert.is.True(plugin.is_test_file(file_path))
		end
	end)

	it("should return false for a non-java file", function()
		local non_test_files = {
			"src/main/java/neotest/Neotest.java",
			"src/main/java/neotest/Repository.java",
		}

		for _, file_path in ipairs(non_test_files) do
			assert.is_not.True(plugin.is_test_file(file_path))
		end
	end)
end)
