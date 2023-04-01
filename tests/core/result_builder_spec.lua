local async = require("plenary.async.tests")
local plugin = require("neotest-java")
local Tree = require("neotest.types.tree")

describe("ResultBuilder", function()

  it("builds the results", function()
    --given
    local runSpec = {
      command = [[/usr/bin/java]],
      env = {},
      cwd = [[/home/runner/work/neotest-java/neotest-java]],
      context = {},
      strategy = "java",
      stream = function() end
    }

    local strategyResult = {
      code = 0,
      output = "output"
    }

    local tree = {}

    --when
    local actual = plugin.results(runSpec, strategyResult, tree)

    --then
    print(vim.inspect(actual))


  end)
end)

