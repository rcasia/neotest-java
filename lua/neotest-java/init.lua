-- current dir
local FileChecker = require("neotest-java.core.file_checker")
local RootFinder = require("neotest-java.core.root_finder")
local DirFilter = require("neotest-java.core.dir_filter")
local PositionsDiscoverer = require("neotest-java.core.positions_discoverer")
local SpecBuilder = require("neotest-java.core.spec_builder")
local ResultBuilder = require("neotest-java.core.result_builder")

---@class neotest.Adapter
---@field name string
NeotestJavaAdapter = { name = "neotest-java" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function NeotestJavaAdapter.root(dir)
  print("neotest-java: root")
	local a = RootFinder.findRoot(dir)
  print("root: " .. tostring(a) .. " -> dir: " .. dir)
  return a
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function NeotestJavaAdapter.filter_dir(name, rel_path, root)
  -- print("neotest-java: filter_dir")
	local a = DirFilter.filter_dir(name, rel_path, root)
  -- print("filter_dir: " .. tostring(a) .. " -> name: " .. name .. " -> rel_path: " .. rel_path .. " -> root: " .. root)
  return a
end

---@async
---@param file_path string
---@return boolean
function NeotestJavaAdapter.is_test_file(file_path)
	return FileChecker.isTestFile(file_path)
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function NeotestJavaAdapter.discover_positions(file_path)
  print("neotest-java: discover_positions")
	return PositionsDiscoverer:discover_positions(file_path)
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function NeotestJavaAdapter.build_spec(args)
  print("neotest-java: build_spec")
	return SpecBuilder.build_spec(args)
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function NeotestJavaAdapter.results(spec, result, tree)
  print("neotest-java: results")
	local results = ResultBuilder.build_results(spec, result, tree)
  print("results: " .. vim.inspect(results))
  return results
end

return NeotestJavaAdapter
