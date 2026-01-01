local root_finder = require("neotest-java.core.root_finder")

describe("RootFinder", function()
	it("should find the root when matcher matches", function()
		-- given
		local function matcher()
			return function(dir)
				return dir
			end
		end
		local dir = "example/dir"

		-- when
		local actualRoot = root_finder.find_root(dir, matcher)

		-- then
		assert.are.same(dir, actualRoot)
	end)

	it("should not find the root when matcher does not match", function()
		-- given
		local function matcher()
			return function()
				return nil
			end
		end
		local dir = "example/dir"

		-- when
		local actualRoot = root_finder.find_root(dir, matcher)

		-- then
		assert.is_nil(actualRoot)
	end)
end)
