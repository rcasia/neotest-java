local File = require("neotest.lib.file")

local file_checker = require("neotest-java.core.file_checker")
local root_finder = require("neotest-java.core.root_finder")
local dir_filter = require("neotest-java.core.dir_filter")
local position_discoverer = require("neotest-java.core.positions_discoverer")
local spec_builder = require("neotest-java.core.spec_builder")
local result_builder = require("neotest-java.core.result_builder")
local log = require("neotest-java.logger")
local ch = require("neotest-java.context_holder")
local Path = require("neotest-java.util.path")

local junit_version = ch.config().default_version

local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")

--- @param filepath neotest-java.Path
local check_junit_jar = function(filepath)
	local exists, _ = File.exists(filepath.to_string())
	assert(
		exists,
		([[
    Junit Platform Console Standalone jar not found at %s
    Please run the following command to download it: NeotestJava setup
    Or alternatively, download it from https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar
  ]]):format(filepath, junit_version, junit_version)
	)
end

---@class neotest.Adapter
local NeotestJavaAdapter = {
	name = "neotest-java",
	filter_dir = dir_filter.filter_dir,
	is_test_file = file_checker.is_test_file,
	discover_positions = position_discoverer.discover_positions,
	results = result_builder.build_results,
	root = function(dir)
		local root = root_finder.find_root(dir)
		if root then
			ch.set_root(root)
		end
		return root
	end,
	build_spec = function(args)
		check_junit_jar(ch.config().junit_jar)

		return spec_builder.build_spec(args, ch.config())
	end,
	get_classpath = function()
		local classpath_provider = ClasspathProvider({
			client_provider = require("neotest-java.core.spec_builder.compiler.client_provider"),
		})

		local classpaths = classpath_provider.get_classpath(Path("."))
		log.debug("[rcasia] classpath: " .. classpaths)
	end,
}

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
