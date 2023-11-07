-- current dir
local FileChecker = require("neotest-java.core.file_checker")
local RootFinder = require("neotest-java.core.root_finder")
local DirFilter = require("neotest-java.core.dir_filter")
local PositionsDiscoverer = require("neotest-java.core.positions_discoverer")
local SpecBuilder = require("neotest-java.core.spec_builder")
local ResultBuilder = require("neotest-java.core.result_builder")

local function there_is_wrapper_in(path)
	local gradle_wrapper = path .. "/gradlew"
	local maven_wrapper = path .. "/mvnw"
	return vim.fn.filereadable(gradle_wrapper) == 1 or vim.fn.filereadable(maven_wrapper) == 1
end

---@class neotest.Adapter
---@field name string
NeotestJavaAdapter = {
	name = "neotest-java",
	project_type = "maven", -- default to maven
	config = {
		ignore_wrapper = false,
	},
	should_ignore_wrapper = function()
		local config = NeotestJavaAdapter.config
		local ignore_wrapper = config.ignore_wrapper
		if ignore_wrapper ~= nil then
			return ignore_wrapper
		end

		if NeotestJavaAdapter.project_type == "maven" then
			ignore_wrapper = vim.fn.filereadable("mvnw") == 1
		elseif NeotestJavaAdapter.project_type == "gradle" then
			ignore_wrapper = vim.fn.filereadable("gradlew") == 1
		end
		print("ignore_wrapper: " .. tostring(ignore_wrapper))
		return ignore_wrapper
	end,
}

local function is_callable(obj)
	return type(obj) == "function" or (type(obj) == "table" and type(getmetatable(obj).__call) == "function")
end

local function has_wrapper()
	return vim.fn.filereadable("mvnw") == 1 or vim.fn.filereadable("gradlew") == 1
end

local function detect_project_type(root_path)
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

	local ignore_wrapper = NeotestJavaAdapter.config.ignore_wrapper
	if not ignore_wrapper then
		ignore_wrapper = not there_is_wrapper_in(root)
	end
	return SpecBuilder.build_spec(args, NeotestJavaAdapter.project_type, ignore_wrapper)
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function NeotestJavaAdapter.results(spec, result, tree)
	return ResultBuilder.build_results(spec, result, tree)
end

setmetatable(NeotestJavaAdapter, {
	__call = function(_, opts)
		opts = opts or {}
		local config = NeotestJavaAdapter.config or {}
		NeotestJavaAdapter.config = vim.tbl_extend("force", config, opts)
		return NeotestJavaAdapter
	end,
})

return NeotestJavaAdapter
