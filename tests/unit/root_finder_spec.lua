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

	it("prefers .git root when it also contains a gradlew wrapper", function()
		local function matcher(pattern)
			return function(dir)
				if pattern == ".git" then
					return "/repo"
				end
				if pattern == "gradlew" and dir == "/repo" then
					return "/repo"
				end
				if pattern == "build.gradle" and dir == "/repo/module/src" then
					return "/repo/module"
				end
				return nil
			end
		end

		local root = root_finder.find_root("/repo/module/src", matcher)

		assert.are.same("/repo", root)
	end)

	it("prefers .git root when it also contains a mvnw wrapper", function()
		local function matcher(pattern)
			return function(dir)
				if pattern == ".git" then
					return "/repo"
				end
				if pattern == "mvnw" and dir == "/repo" then
					return "/repo"
				end
				if pattern == "pom.xml" and dir == "/repo/module/src" then
					return "/repo/module"
				end
				return nil
			end
		end

		local root = root_finder.find_root("/repo/module/src", matcher)

		assert.are.same("/repo", root)
	end)

	it("prefers .git root when it also contains a build file (multi-module Maven)", function()
		-- /repo has .git and pom.xml; /repo/module has pom.xml (closer)
		-- Expected: /repo (because it has BOTH .git and pom.xml)
		local function matcher(pattern)
			return function(dir)
				if pattern == ".git" then
					return "/repo"
				end
				if pattern == "pom.xml" and dir == "/repo/module/src" then
					return "/repo/module"
				end
				if pattern == "pom.xml" and dir == "/repo" then
					return "/repo"
				end
				return nil
			end
		end

		local root = root_finder.find_root("/repo/module/src", matcher)

		assert.are.same("/repo", root)
	end)

	it("falls back to nearest build file when .git root has no build file or wrapper", function()
		-- /repo has .git but no build file; /repo/module has pom.xml
		-- Expected: /repo/module (nearest build file)
		local function matcher(pattern)
			return function(dir)
				if pattern == ".git" then
					return "/repo"
				end
				if pattern == "pom.xml" and dir == "/repo/module/src" then
					return "/repo/module"
				end
				-- /repo itself has no pom.xml (matcher returns nil when called with /repo)
				return nil
			end
		end

		local root = root_finder.find_root("/repo/module/src", matcher)

		assert.are.same("/repo/module", root)
	end)

	it("falls back to .git alone when no build file or wrapper exists anywhere", function()
		local function matcher(pattern)
			return function(_)
				if pattern == ".git" then
					return "/repo"
				end
				return nil
			end
		end

		local root = root_finder.find_root("/repo/module/src", matcher)

		assert.are.same("/repo", root)
	end)
end)
