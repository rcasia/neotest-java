local async = require("nio").tests
local plugin = require("neotest-java")

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
		-- local tree = function()
      -- return {
        -- data = function()
          -- return {
            -- path = "/home/rcasia/REPOS/opensource/neotest-java/tests/fixtures/Test.java",
            -- name = "shouldNotFail",
          -- }
        -- end,
      -- }
    -- end
    --
    local tree = plugin.discover_positions("/home/rcasia/REPOS/opensource/neotest-java/tests/fixtures/Test.java")
    -- print (vim.inspect(positions))

		--when
		local actual = plugin.results(runSpec, strategyResult, tree)

		--then
		print(vim.inspect(actual))
	end)
end)
