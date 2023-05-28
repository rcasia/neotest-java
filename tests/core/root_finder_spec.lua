local async = require("plenary.async.tests")
local plugin = require("neotest-java")
local Tree = require("neotest.types").Tree

describe("RootFinder", function()
	it("should find the root of a project", function()
		-- given
		local absoluteDirs = {
			"/home/user/project/src/main/java",
			"/home/user/project/src/main/resources",
			"/home/user/project/src/test/java",
			"/home/user/project/src/test/resources",
			"/home/user/project",
		}

		local expectedRoot = "/home/user/project"

		-- when
		for _, dir in ipairs(absoluteDirs) do
			local actualRoot = plugin.root(dir)

			-- then
			assert.are.same(expectedRoot, actualRoot)
		end
	end)
end)
