local File = require("neotest.lib.file")

local FileChecker = require("neotest-java.core.file_checker")
local root_finder = require("neotest-java.core.root_finder")
local dir_filter = require("neotest-java.core.dir_filter")
local position_discoverer = require("neotest-java.core.positions_discoverer")
local spec_builder = require("neotest-java.core.spec_builder")
local result_builder = require("neotest-java.core.result_builder")
local log = require("neotest-java.logger")
local ch = require("neotest-java.context_holder")
local Path = require("neotest-java.model.path")
local nio = require("nio")

local DEFAULT_CONFIG = require("neotest-java.default_config")

--- @param filepath neotest-java.Path
local check_junit_jar = function(filepath, default_version)
	local exists, _ = File.exists(filepath:to_string())
	assert(
		exists,
		([[
    Junit Platform Console Standalone jar not found at %s
    Please run the following command to download it: NeotestJava setup
    Or alternatively, download it from https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar
  ]]):format(filepath, default_version, default_version)
	)
end

local mkdir = function(dir)
	vim.uv.fs_mkdir(dir:to_string(), 493)
end

local chdir = function(dir)
	nio.fn.chdir(dir:to_string())
end

--- @param config neotest-java.ConfigOpts
--- @return neotest.Adapter
local function NeotestJavaAdapter(config)
	config = config or {}

	ch.set_opts(config)

	log.info("neotest-java adapter initialized")

	-- create data directory if it doesn't exist
	mkdir(Path(vim.fn.stdpath("data")):append("neotest-java"))

	local root = Path(root_finder.find_root(vim.fn.getcwd()))
	local root_getter = function()
		return root
	end
	local file_checker = FileChecker({
		root_getter = root_getter,
		patterns = config.test_classname_patterns,
	})
	return setmetatable({

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
			check_junit_jar(config.junit_jar, config.default_version)

			return spec_builder.build_spec(args, config, {
				root_getter = root_getter,
				mkdir = mkdir,
				chdir = chdir,
			})
		end,
	}, {
		__call = function(_, _opts)
			local user_opts = vim.tbl_extend("force", config, _opts or {})
			return NeotestJavaAdapter(user_opts)
		end,
	})
end

return NeotestJavaAdapter(DEFAULT_CONFIG)
