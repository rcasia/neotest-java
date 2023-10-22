-- current dir
local FileChecker = require("neotest-java.core.file_checker")
local RootFinder = require("neotest-java.core.root_finder")
local DirFilter = require("neotest-java.core.dir_filter")
local PositionsDiscoverer = require("neotest-java.core.positions_discoverer")
local SpecBuilder = require("neotest-java.core.spec_builder")
local ResultBuilder = require("neotest-java.core.result_builder")

---@class neotest.Adapter
---@field name string
NeotestJavaAdapter = {
	name = "neotest-java",
	project_type = "maven", -- default to maven
	ignore_wrapper = false, -- default to false
}

function detect_project_type(root_path)
	local gradle_build_file = root_path .. "/build.gradle"
	local maven_build_file = root_path .. "/pom.xml"
	if vim.fn.filereadable(gradle_build_file) == 1 then
		return "gradle"
	elseif vim.fn.filereadable(maven_build_file) == 1 then
		return "maven"
	end
end

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function NeotestJavaAdapter.root(dir)
	return RootFinder.find_root(dir)
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function NeotestJavaAdapter.filter_dir(name, rel_path, root)
	return DirFilter.filter_dir(name, rel_path, root)
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
	return PositionsDiscoverer:discover_positions(file_path)
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function NeotestJavaAdapter.build_spec(args)
	local root = NeotestJavaAdapter.root(args.tree:data().path)
	NeotestJavaAdapter.project_type = detect_project_type(root)
	return SpecBuilder.build_spec(args, NeotestJavaAdapter.project_type, NeotestJavaAdapter.ignore_wrapper)
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function NeotestJavaAdapter.results(spec, result, tree)
	return ResultBuilder.build_results(spec, result, tree)
end

function is_callable(obj)
	return type(obj) == "function" or (type(obj) == "table" and type(getmetatable(obj).__call) == "function")
end

function check_wrapper()
	local has_wrapper = vim.fn.filereadable("mvnw") == 1 or vim.fn.filereadable("gradlew") == 1
	if not has_wrapper then
		NeotestJavaAdapter.ignore_wrapper = true
	end
end

setmetatable(NeotestJavaAdapter, {
	__call = function(_, opts)
		if is_callable(opts.ignore_wrapper) then
			NeotestJavaAdapter.ignore_wrapper = opts.ignore_wrapper()
		elseif opts.ignore_wrapper ~= nil then
			NeotestJavaAdapter.ignore_wrapper = opts.ignore_wrapper
		end

		-- if the project doesn't have wrapper, ignore it
		check_wrapper()

		return NeotestJavaAdapter
	end,
})

return NeotestJavaAdapter
