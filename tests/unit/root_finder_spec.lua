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

	it("should find build.gradle before .git", function()
		local call_order = {}
		local function create_matcher(pattern)
			return function(_)
				table.insert(call_order, pattern)
				if pattern == "build.gradle" then
					return "found_build_gradle"
				end
				return nil
			end
		end

		local dir = "example/dir"
		local actualRoot = root_finder.find_root(dir, create_matcher)

		assert.are.same("found_build_gradle", actualRoot)
		assert.is_true(
			call_order[1] == "pom.xml" or call_order[1] == "settings.gradle" or call_order[1] == "settings.gradle.kts"
		)
		assert.is_true(call_order[#call_order] == "build.gradle")
	end)
end)
