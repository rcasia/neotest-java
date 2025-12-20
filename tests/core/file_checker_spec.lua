local plugin = require("neotest-java")
local it = require("nio").tests.it -- async

describe("file_checker", function()
	it("should return true for test files", function()
		local test_files = {
			"src/test/java/neotest/NeotestTest.java",
			"src/test/java/neotest/RepositoryTests.java",
			"src/test/java/neotest/NeotestIT.java",
			"src/test/java/neotest/ProductAceptanceTests.java",
			"src/test/java/neotest/domain/ProductAceptanceTests.java",
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

	it("should return true if theres a /main/ outside the root path", function()
		local ch = require("neotest-java.context_holder")
		ch.set_root("/absolute_path/main/src")
		local non_test_files = {
			"/absolute_path/main/src/java/neotest/NeotestTest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_true(plugin.is_test_file(file_path))
		end
		ch.set_root("")
	end)

	it("should return false if theres a /main/ inside the root path in a windows env", function()
		vim.fn.win64 = {}
		local ch = require("neotest-java.context_holder")
		ch.set_root("C:\\absolute_path\\main\\src")

		local non_test_files = {
			"C:\\absolute_path\\src\\main\\java\\neotest\\NeotestTest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_false(plugin.is_test_file(file_path))
		end

		ch.set_root("")
		vim.fn.win64 = nil
	end)

	it("should return true if theres a /main/ outside the root path in a windows env", function()
		vim.fn.win64 = {}
		local ch = require("neotest-java.context_holder")
		ch.set_root("C:\\absolute_path\\main\\src")

		local non_test_files = {
			"C:\\absolute_path\\main\\src\\java\\neotest\\NeotestTest.java",
		}
		for _, file_path in ipairs(non_test_files) do
			assert.is_true(plugin.is_test_file(file_path))
		end

		ch.set_root("")
		vim.fn.win64 = nil
	end)
end)
