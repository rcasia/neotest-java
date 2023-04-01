---@class neotest.Result
---@field status "passed"|"failed"|"skipped"
---@field output? string Path to file containing full output data
---@field short? string Shortened output string
---@field errors? neotest.Error[]

ResultBuilder = {}
  ---@async
  ---@param spec neotest.RunSpec
  ---@param result neotest.StrategyResult
  ---@param tree neotest.Tree
  ---@return table<string, neotest.Result>
  function ResultBuilder.build_results(spec, result, tree)
    local results = {}

    results["prueba"] = {
      status = "skipped",
      output = "output",
      short = "short",
      errors = {
        {
          message = "message",
          trace = "trace"
        }
      }
    }

    return results
  end


return ResultBuilder

