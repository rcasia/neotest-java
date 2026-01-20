local File = require("neotest.lib.file")

local FileChecker = require("neotest-java.core.file_checker")
local root_finder = require("neotest-java.core.root_finder")
local dir_filter = require("neotest-java.core.dir_filter")
local PositionDiscoverer = require("neotest-java.core.positions_discoverer")
local SpecBuilder = require("neotest-java.core.spec_builder")
local result_builder = require("neotest-java.core.result_builder")
local log = require("neotest-java.logger")
local ch = require("neotest-java.context_holder")
local Path = require("neotest-java.model.path")
local nio = require("nio")
local logger = require("neotest-java.logger")
local Binaries = require("neotest-java.command.binaries")
local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local version_detector = JunitVersionDetector()
local lib = require("neotest.lib")
local exists = require("neotest.lib.file").exists

local DEFAULT_CONFIG = require("neotest-java.default_config")

local client_provider = require("neotest-java.core.spec_builder.compiler.client_provider")
local MethodIdResolver = require("neotest-java.method_id_resolver")
local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")
local CommandExecutor = require("neotest-java.command.command_executor")
local scan = require("neotest-java.util.dir_scan")
local build_tools = require("neotest-java.build_tool")
local detect_project_type = require("neotest-java.util.detect_project_type")
local compilers = require("neotest-java.core.spec_builder.compiler")

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

--- @class neotest-java.Adapter : neotest.Adapter
--- @field config neotest-java.ConfigOpts
--- @field install fun()
---

--- @class neotest-java.Dependencies
--- @field root_finder { find_root: fun(dir: string): string | nil }

--- @param config neotest-java.ConfigOpts
--- @param deps? neotest-java.Dependencies
--- @return neotest-java.Adapter
local function NeotestJavaAdapter(config, deps)
	config = vim.tbl_extend("force", DEFAULT_CONFIG, config or {})
	deps = deps or {}
	local _root_finder = deps and deps.root_finder or root_finder

	log.info("neotest-java adapter initialized")

	logger.debug("config: " .. vim.inspect(config))

	-- create data directory if it doesn't exist
	mkdir(Path(vim.fn.stdpath("data")):append("neotest-java"))

	-- Check for JUnit jar updates (only if user hasn't disabled notifications and not already shown)
	if not config.disable_update_notifications and not ch.update_notification_shown then
		local existing_version, _ = version_detector.detect_existing_version()
		if existing_version then
			local has_update, latest_version = version_detector.check_for_update(existing_version)
			if has_update and latest_version then
				-- Mark notification as shown to avoid duplicates
				ch.update_notification_shown = true
				-- Show notification about available update
				lib.notify(
					string.format(
						"JUnit jar update available: %s → %s. Run :NeotestJava setup to upgrade. (Disable: set disable_update_notifications = true in config)",
						existing_version.version,
						latest_version.version
					),
					"info"
				)
			end
		end
	end

	local cwd = vim.loop.cwd()

	--- @type neotest-java.Path|nil
	local root
	local root_getter = function()
		if root then
			return root
		end
		local _root = _root_finder.find_root(cwd)
		if not _root then
			return nil
		end
		root = Path(_root)
		return root
	end
	local file_checker = FileChecker({
		root_getter = root_getter,
		patterns = config.test_classname_patterns,
	})
	local classpath_provider = ClasspathProvider({
		client_provider = client_provider,
	})
	local binaries = Binaries({
		client_provider = client_provider,
	})
	local spec_builder_instance = SpecBuilder({
		classpath_provider = classpath_provider,
		binaries = binaries,
		root_getter = root_getter,
		mkdir = mkdir,
		chdir = chdir,
		scan = scan,
		compile = function(base_dir, compile_mode)
			compilers.lsp.compile({
				base_dir = base_dir,
				compile_mode = compile_mode,
			})
		end,
		report_folder_name_gen = function(module_dir, build_dir)
			local base = (module_dir and module_dir:append(build_dir:to_string())) or build_dir
			return base:append("junit-reports"):append(nio.fn.strftime("%d%m%y%H%M%S"))
		end,
		build_tool_getter = build_tools.get,
		detect_project_type = detect_project_type,
		launch_debug_test = build_tools.launch_debug_test,
	})
	return setmetatable({

		install = function()
			local Installer = require("neotest-java.install")
			local installer = Installer({
				exists = exists,
				checksum = function(path)
					local f = assert(io.open(path:to_string(), "rb"))
					local data = f:read("*a")
					f:close()
					return vim.fn.sha256(data)
				end,
				download = function(url, output)
					local out = vim.system({
						"curl",
						"--output",
						output,
						url,
						"--create-dirs",
					}):wait(10000)
					return out
				end,
				delete_file = vim.fn.delete,
				ask_user_consent = function(msg, chs, cb)
					vim.ui.select(chs, {
						prompt = msg,
					}, function(choice)
						cb(choice)
					end)
				end,
				notify = lib.notify,
				detect_existing_version = version_detector.detect_existing_version,
			})
			installer.install(config)
		end,
		config = config,
		name = "neotest-java",
		filter_dir = dir_filter.filter_dir,
		is_test_file = file_checker.is_test_file,
		discover_positions = PositionDiscoverer({
			method_id_resolver = MethodIdResolver({
				classpath_provider = classpath_provider,
				command_executor = CommandExecutor(),
				binaries = binaries,
			}),
		}).discover_positions,
		results = result_builder.build_results,
		root = function(dir)
			return _root_finder.find_root(dir)
		end,
		build_spec = function(args)
			check_junit_jar(config.junit_jar, config.default_junit_jar_version.version)
			return spec_builder_instance.build_spec(args, config)
		end,
	}, {
		__call = function(_, opts, user_deps)
			local user_opts = vim.tbl_extend("force", DEFAULT_CONFIG, opts or {})

			if type(user_opts.junit_jar) == "string" then
				user_opts.junit_jar = Path(user_opts.junit_jar)
			end
			ch.adapter = NeotestJavaAdapter(user_opts, user_deps)
			return ch.adapter
		end,
	})
end

ch.adapter = NeotestJavaAdapter(DEFAULT_CONFIG)

return ch.adapter
