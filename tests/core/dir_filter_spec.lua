local async = require("plenary.async.tests")
local plugin = require("neotest-java")
local Tree = require("neotest.types").Tree

describe("DirFilter", function()
	it("should filter out excluded directories", function()
		local relative_paths = {
			"src/main/java/com/example/",
			"build/classes/com/example/Example.class",
			"out/classes/com/example/Example.class",
			"bin/classes/com/example/Example.class",
			"resources/classes/com/example/Example.class",
			"target/classes/com/example/Example.class",
			"src/main/java/com/example/Example.java",
		}

		local root = "/home/user/project"

		local name = "java"

		-- then
		for _, path in ipairs(relative_paths) do
			local result = plugin.filter_dir(name, path, root)

			-- print path when test fails
			if result then
				print("Expected to filter out: " .. path)
			end

			assert.is_false(result)
		end
	end)

	it("should not filter out directories test directories", function()
		local relative_paths = {
			"src/test/java/com/example/",
			"src/test/java/com/example/Example.java",
			"src/test/java/com/example/ExampleTest.java",
		}

		local root = "/home/user/project"

		local name = "java"

		-- then
		for _, path in ipairs(relative_paths) do
			local result = plugin.filter_dir(name, path, root)

			-- print path when test fails
			if not result then
				print("Expected to not filter out: " .. path)
			end
			assert.is_true(result)
		end
	end)
end)
