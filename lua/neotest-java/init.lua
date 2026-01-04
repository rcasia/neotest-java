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
local exists = require("neotest.lib.file").exists
local logger = require("neotest-java.logger")
local lib = require("neotest.lib")

local DEFAULT_CONFIG = require("neotest-java.default_config")

--- @param filepath neotest-java.Path
local check_junit_jar = function(filepath, default_version)
	local _exists, _ = File.exists(filepath:to_string())
	assert(
		_exists,
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
local install = function(config)
	local filepath = config.junit_jar:to_string()

	if exists(filepath) then
		lib.notify("Already setup!")
		return
	end

	vim.system(
		{
			"curl",
			"--output",
			filepath,
			("https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar"):format(
				config.default_version,
				config.default_version
			),
			"--create-dirs",
		},
		nil,
		function(out)
			if out.code == 0 then
				lib.notify("Downloaded Junit Standalone successfully!")
			else
				lib.notify(string.format("Error while downloading: \n %s", out.stderr), "error")
				logger.error(out.stderr)
			end
		end
	)
end

--- @class neotest-java.Adapter : neotest.Adapter
--- @field config neotest-java.ConfigOpts
--- @field install fun()

--- @param config neotest-java.ConfigOpts
--- @return neotest-java.Adapter
local function NeotestJavaAdapter(config)
	config = config or {}

	log.info("neotest-java adapter initialized")

	logger.debug("config: " .. vim.inspect(config))

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

		install = function()
			install(config)
		end,
		config = config,
		name = "neotest-java",
		filter_dir = dir_filter.filter_dir,
		is_test_file = file_checker.is_test_file,
		discover_positions = position_discoverer.discover_positions,
		results = result_builder.build_results,
		root = function(dir)
			return root_finder.find_root(dir)
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

			if type(user_opts.junit_jar) == "string" then
				user_opts.junit_jar = Path(user_opts.junit_jar)
			end
			ch.adapter = NeotestJavaAdapter(user_opts)
			return ch.adapter
		end,
	})
end

ch.adapter = NeotestJavaAdapter(DEFAULT_CONFIG)

return ch.adapter
