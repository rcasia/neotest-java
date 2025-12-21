local nio = require("nio")
local Path = require("neotest-java.util.path")
local scan = require("neotest-java.util.dir_scan")

local eq = assert.are.same
local it = nio.tests.it

describe("Dir Scan", function()
	it("scans", function()
		local target_dir = Path(".")

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
			Path("build"),
		}, scan(target_dir, test_dependencies))
	end)
end)
