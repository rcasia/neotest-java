local nio = require("nio")
local Path = require("neotest-java.util.path")
local scan = require("neotest-java.util.dir_scan")

local eq = assert.are.same
local it = nio.tests.it

describe("Dir Scan", function()
	it("scans", function()
		local target_dir = Path(".")
		local expected_dirs = {
			Path("some-random.log"),
			Path("src"),
			Path("tests"),
			Path("build"),
		}

		local test_dependencies = {
			iter_dir = function(dir)
				assert(target_dir == dir, "should be called with correct dir")

				local index = 0

				return function()
					index = index + 1
					return expected_dirs[index]
				end
			end,
		}

		-- with empty opts
		local empty_opts = {}
		eq(expected_dirs, scan(target_dir, empty_opts, test_dependencies))

		-- with nil opts
		local nil_opts = nil
		eq(expected_dirs, scan(target_dir, nil_opts, test_dependencies))
	end)

	it("scans with a search pattern", function()
		local target_dir = Path(".")
		local opts = {
			search_patterns = {
				"src",
				"tests",
			},
		}

		local test_dependencies = {
			iter_dir = function(dir)
				assert(target_dir == dir, "should be called with correct dir")

				local dirs = {
					Path("some-random.log"),
					Path("src"),
					Path("tests"),
					Path("build"),
				}

				local index = 0

				return function()
					index = index + 1
					return dirs[index]
				end
			end,
		}

		eq({
			Path("src"),
			Path("tests"),
		}, scan(target_dir, opts, test_dependencies))
	end)
end)
