local async = require("plenary.async").tests
local plugin = require("neotest-java")
local Tree = require("neotest.types.tree")

describe("ResultBuilder", function()
	async.it("builds the results", function()
		--given
		local runSpec = {
			command = [[/usr/bin/java]],
			env = {},
			cwd = [[/home/rcasia/REPOS/opensource/neotest-java/tests/fixtures/demo]],
			context = {},
			strategy = "java",
			stream = function() end,
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

    -- local positions = plugin.discover_positions("/home/rcasia/REPOS/opensource/neotest-java/tests/fixtures/Test.java"):to_list()
    -- print (vim.inspect(positions))
		-- local tree = Tree.from_list(positions)

    local tree = {}

		--when
		local actual = plugin.results(runSpec, strategyResult, tree)

		--then
		print(vim.inspect(actual))
	end)
end)
