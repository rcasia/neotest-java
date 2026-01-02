local plugin = require("neotest-java")
local FileChecker = require("neotest-java.core.file_checker")
local Path = require("neotest-java.model.path")

describe("file_checker", function()
	it("should return true for test files", function()
		local base_path = Path("/home/user/repo/")
		local test_dependencies = {
			root_getter = function()
				return base_path
			end,
		}
		local test_files = {
			base_path:append("src/test/java/neotest/NeotestTest.java"):to_string(),
			base_path:append("src/test/java/neotest/RepositoryTests.java"):to_string(),
			base_path:append("src/test/java/neotest/NeotestIT.java"):to_string(),
			base_path:append("src/test/java/neotest/ProductAceptanceTests.java"):to_string(),
			base_path:append("src/test/java/neotest/domain/ProductAceptanceTests.java"):to_string(),
		}

		for _, file_path in ipairs(test_files) do
			assert.is_true(FileChecker.is_test_file(file_path, test_dependencies), file_path)
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

	it("should return true if theres a /main/ outside the root path", function()
		local base_path = Path("/absolute_path/main/src")
		local test_dependencies = {
			root_getter = function()
				return base_path
			end,
		}
		local non_test_files = {
			"/absolute_path/main/src/java/neotest/NeotestTest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_true(FileChecker.is_test_file(file_path, test_dependencies))
		end
	end)

	it("should return false if theres a /main/ inside the root path in a windows env", function()
		local base_path = Path("C:\\absolute_path\\src")
		local test_dependencies = {
			root_getter = function()
				return base_path
			end,
		}
		local non_test_files = {
			"C:\\absolute_path\\src\\main\\java\\neotest\\NeotestTest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_false(FileChecker.is_test_file(file_path, test_dependencies))
		end
	end)

	it("should return true if theres a /main/ outside the root path in a windows env", function()
		local test_dependencies = {
			root_getter = function()
				return Path("C:\\absolute_path\\main\\src")
			end,
		}
		local non_test_files = {
			"C:\\absolute_path\\main\\src\\java\\neotest\\NeotestTest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_true(FileChecker.is_test_file(file_path, test_dependencies))
		end
	end)
end)
