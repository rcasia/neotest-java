local async = require("plenary.async.tests")
local plugin = require("neotest-java")
local Tree = require("neotest.types").Tree

describe("DirFilter", function()
	it("should filter out directories", function()
		local relative_paths = {
			"src/main/java/com/example/",
			"src/main/java/com/example/Example.java",
			"src/main/java/com/example/ExampleTest.java",
		}

		local root = "/home/user/project"

		local name = "java"

		-- then
		for _, path in ipairs(relative_paths) do
			local result = plugin:filter_dir(name, path, root)
			assert.is_false(result)
		end
	end)

	it("should not filter out directories", function()
		local relative_paths = {
			"src/test/java/com/example/",
			"src/test/java/com/example/Example.java",
			"src/test/java/com/example/ExampleTest.java",
		}

		local root = "/home/user/project"

		local name = "java"

		-- then
		for _, path in ipairs(relative_paths) do
			local result = plugin:filter_dir(name, path, root)
			assert.is_true(result)
		end
	end)
end)
