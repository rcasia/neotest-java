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

local detect_project_type = require("neotest-java.util.detect_project_type")

local check_junit_jar = function(filepath)
	local exists, _ = File.exists(filepath)
	assert(
		exists,
		([[
    Junit Platform Console Standalone jar not found at %s
    Please run the following command to download it: NeotestJava setup
    Or alternatively, download it from https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.1/junit-platform-console-standalone-1.10.1.jar
  ]]):format(filepath)
	)
end

---@type neotest-java.Timer
local test_timer = nil

---@type neotest.Adapter
local NeotestJavaAdapter = {
	name = "neotest-java",
	root = function(dir)
		local root = root_finder.find_root(dir)
		if root then
			ch.set_root(root)
		end
		return root
	end,
	filter_dir = dir_filter.filter_dir,
	is_test_file = file_checker.is_test_file,
	discover_positions = position_discoverer.discover_positions,

	build_spec = function(args)
		test_timer = timer.start()
		check_junit_jar(ch.get_context().config.junit_jar)

		-- TODO: find a way to avoid to make this steps every time

		-- find root
		local root = ch.get_context().root or root_finder.find_root(vim.fn.getcwd())
		assert(root, "root directory not found")

		-- detect project type
		local project_type = detect_project_type(root)

		-- build spec
		return spec_builder.build_spec(args, project_type, ch.get_context().config)
	end,
	results = function(spec, result, tree)
		local results = result_builder.build_results(spec, result, tree)

		if test_timer then
			lib.notify("Tests lasted " .. test_timer:stop() .. " ms.")
		end

		return results
	end,
};

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
