local async = require("nio").tests
local plugin = require("neotest-java")

local function getCurrentDir()
	return vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
end

describe("ResultBuilder", function()
	async.it("builds the results", function()
		--given
		local runSpec = {
			-- TODO: use a real test runner
			command = [[/usr/bin/java]],
			env = {},
			cwd = getCurrentDir() .. "tests/fixtures/demo",
			context = {},
			strategy = "java",
			stream = function() end,
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = getCurrentDir() .. "tests/fixtures/demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local actual = plugin.results(runSpec, strategyResult, tree)

		--then
		print(vim.inspect(actual))
	end)
end)
