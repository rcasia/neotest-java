local nio = require("nio")
local Path = require("neotest-java.util.path")
local scan = require("neotest-java.util.dir_scan")

local eq = require("tests.assertions").eq
local it = nio.tests.it

describe("Dir Scan", function()
	it("scans", function()
		local target_dir = Path(".")

		local nested_dirs = {
			[Path(".").to_string()] = {
				Path("./some"),
			},

			[Path("./some").to_string()] = {
				Path("./some/inner"),
				Path("./some/random.log"),
			},

			[Path("./some/inner").to_string()] = {
				Path("./some/inner/image.png"),
			},
		}

		local test_dependencies = {
			iter_dir = function(dir)
				assert(dir ~= Path("./some/random.log"), "should not scan files. found: " .. dir.to_string())
				assert(dir ~= Path("./some/inner/image.png"), "should not scan files. found: " .. dir.to_string())
				local dirs = nested_dirs[dir.to_string()] or {}

				local index = 0

				return function()
					index = index + 1
					local new_path = dirs[index]
					if new_path == nil then
						return nil
					end
					local typ = nested_dirs[new_path.to_string()] and "directory" or "file"
					return { path = dirs[index], typ = typ }
				end
			end,
		}

		-- with empty opts
		local empty_opts = {}
		local result = scan(target_dir, empty_opts, test_dependencies)
		eq({
			Path("./some"),
			Path("./some/inner"),
			Path("./some/random.log"),
			Path("./some/inner/image.png"),
		}, result)

		-- with nil opts should be the same
		local nil_opts = nil
		eq(result, scan(target_dir, nil_opts, test_dependencies))

		-- with search patterns
		local opts = {
			search_patterns = { "log$" },
		}
		eq({
			Path("./some/random.log"),
		}, scan(target_dir, opts, test_dependencies))
	end)
end)
