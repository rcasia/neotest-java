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

	it("should find build.gradle before .git for single-module Gradle projects", function()
		local patterns_checked = {}
		local matcher = function(pattern)
			table.insert(patterns_checked, pattern)
			return function(_)
				if pattern == "build.gradle" then
					return "/path/to/project"
				end
				return nil
			end
		end

		local root = root_finder.find_root("/some/dir", matcher)

		assert.are.same("/path/to/project", root)
		assert.is_true(patterns_checked[#patterns_checked] == "build.gradle")
		assert.is_true(patterns_checked[#patterns_checked - 1] ~= ".git")
	end)
end)
