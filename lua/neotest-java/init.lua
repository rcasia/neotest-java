---@diagnostic disable: undefined-doc-name, duplicate-doc-field, duplicate-set-field

local File = require("neotest.lib.file")

local file_checker = require("neotest-java.core.file_checker")
local root_finder = require("neotest-java.core.root_finder")
local dir_filter = require("neotest-java.core.dir_filter")
local position_discoverer = require("neotest-java.core.positions_discoverer")
local spec_builder = require("neotest-java.core.spec_builder")
local result_builder = require("neotest-java.core.result_builder")
local log = require("neotest-java.logger")
local ch = require("neotest-java.context_holder")
local lib = require("neotest.lib")
local timer = require("neotest-java.util.timer")
local nio = require("nio")

local detect_project_type = require("neotest-java.util.detect_project_type")

local check_junit_jar = function(filepath)
	local exists, err = File.exists(filepath)
	assert(
		exists,
		([[
    Junit Platform Console Standalone jar not found at %s
    Please run the following command to download it: NeotestJava setup
    Or alternatively, download it from https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.1/junit-platform-console-standalone-1.10.1.jar
  ]]):format(filepath)
	)
end

---@class neotest.Adapter
NeotestJavaAdapter = {
	name = "neotest-java",
}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function NeotestJavaAdapter.root(dir)
	local root = root_finder.find_root(dir)
	if root then
		ch.set_root(root)
	end
	return root
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function NeotestJavaAdapter.filter_dir(name, rel_path, root)
	return dir_filter.filter_dir(name, rel_path, root)
end

---@async
---@param file_path string
---@return boolean
function NeotestJavaAdapter.is_test_file(file_path)
	return file_checker.is_test_file(file_path)
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function NeotestJavaAdapter.discover_positions(file_path)
	return position_discoverer.discover_positions(file_path)
end

---@type neotest-java.Timer
local test_timer = nil

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function NeotestJavaAdapter.build_spec(args)
	test_timer = timer:start()
	local self = NeotestJavaAdapter
	check_junit_jar(ch.get_context().config.junit_jar)

	-- TODO: find a way to avoid to make this steps every time

	-- find root
	local root = ch.get_context().root or self.root(vim.fn.getcwd())
	assert(root, "root directory not found")

	-- detect project type
	local project_type = detect_project_type(root)

	-- build spec
	return spec_builder.build_spec(args, project_type, ch.get_context().config)
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function NeotestJavaAdapter.results(spec, result, tree)
	local results = result_builder.build_results(spec, result, tree)

	if test_timer then
		lib.notify("Tests lasted " .. test_timer:stop() .. " ms.")
	end

	return results
end

-- on init
(function()
	log.info("neotest-java adapter initialized")

	-- create data directory if it doesn't exist
	local data_dir = vim.fn.stdpath("data") .. "/neotest-java"
	vim.uv.fs_mkdir(data_dir, 493)
end)()

setmetatable(NeotestJavaAdapter, {
	__call = function(_, opts)
		opts = opts or {}

		ch.set_opts(opts)

		return NeotestJavaAdapter
	end,
})

return NeotestJavaAdapter
