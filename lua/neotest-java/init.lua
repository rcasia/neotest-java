local File = require("neotest.lib.file")
local lib = require("neotest.lib")

local FileChecker = require("neotest-java.core.file_checker")
local root_finder = require("neotest-java.core.root_finder")
local dir_filter = require("neotest-java.core.dir_filter")
local PositionDiscoverer = require("neotest-java.core.positions_discoverer")
local SpecBuilder = require("neotest-java.core.spec_builder")
local ResultBuilder = require("neotest-java.core.result_builder")
local JunitResultReader = require("neotest-java.core.junit_result_reader")
local XmlReader = require("neotest-java.util.xml_reader")
local logger = require("neotest-java.logger")
local ch = require("neotest-java.context_holder")
local Path = require("neotest-java.model.path")
local nio = require("nio")
local Binaries = require("neotest-java.command.binaries")
local checksum = require("neotest-java.util.checksum")
local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local MethodIdResolver = require("neotest-java.method_id_resolver")
local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")
local CommandExecutor = require("neotest-java.command.command_executor")
local scan = require("neotest-java.util.dir_scan")
local build_tools = require("neotest-java.build_tool")
local launcher = require("neotest-java.build_tool.launcher")
local detect_project_type = require("neotest-java.util.detect_project_type")
local compilers = require("neotest-java.core.spec_builder.compiler")
local DEFAULT_CONFIG = require("neotest-java.default_config")
local read_file = require("neotest-java.util.read_file")

local DEFAULT_VERSION_DETECTOR_DEPS = {
	exists = function(path)
		return File.exists(path:to_string())
	end,
	checksum = function(path)
		local hash, err = checksum.sha256(path:to_string())
		if not hash then
			error(err)
		end
		return hash
	end,
	scan = scan,
	stdpath_data = vim.fn.stdpath,
}

local version_detector = JunitVersionDetector(DEFAULT_VERSION_DETECTOR_DEPS)

local function mkdir(dir)
	vim.uv.fs_mkdir(dir:to_string(), 493)
end

local function report_folder_name_gen(module_dir, build_dir)
	local base = (module_dir and module_dir:append(build_dir:to_string())) or build_dir
	return base:append("junit-reports"):append(nio.fn.strftime("%d%m%y%H%M%S"))
end

local function remove_file(filepath)
	local ok, err = pcall(os.remove, filepath)
	if not ok then
		return false, tostring(err)
	end
	return true
end

--- @class neotest-java.Adapter : neotest.Adapter
--- @field config neotest-java.ConfigOpts
--- @field install fun()

---@class neotest-java.CheckJunitJarDeps
---@field file_exists? fun(filepath: string): boolean
---@field version_detector? neotest-java.JunitVersionDetector

--- @class neotest-java.Dependencies
--- @field root_finder? { find_root: fun(dir: string): string | nil }
--- @field check_junit_jar_deps? neotest-java.CheckJunitJarDeps
---@diagnostic disable-next-line: undefined-doc-name
--- @field client_provider? fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field classpath_provider? neotest-java.ClasspathProvider
--- @field binaries? neotest-java.LspBinaries
--- @field lsp_compiler? NeotestJavaCompiler
--- @field build_tool_getter? fun(project_type: string): neotest-java.BuildTool
--- @field method_id_resolver? neotest-java.MethodIdResolver

--- @class neotest-java.ResolvedDeps
--- @field root_finder { find_root: fun(dir: string): string | nil }
--- @field check_junit_jar_deps neotest-java.CheckJunitJarDeps
---@diagnostic disable-next-line: undefined-doc-name
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field classpath_provider neotest-java.ClasspathProvider
--- @field binaries neotest-java.LspBinaries
--- @field lsp_compiler NeotestJavaCompiler
--- @field build_tool_getter fun(project_type: string): neotest-java.BuildTool
--- @field method_id_resolver neotest-java.MethodIdResolver

--- @param deps neotest-java.Dependencies | nil
--- @return neotest-java.ResolvedDeps
local function resolve_deps(deps)
	deps = deps or {}
	local _client_provider = deps.client_provider or compilers.client_provider
	local _classpath_provider = deps.classpath_provider or ClasspathProvider({ client_provider = _client_provider })
	local _binaries = deps.binaries or Binaries({ client_provider = _client_provider })
	local _method_id_resolver = deps.method_id_resolver
		or MethodIdResolver({
			classpath_provider = _classpath_provider,
			command_executor = CommandExecutor(),
			binaries = _binaries,
		})

	return {
		root_finder = deps.root_finder or root_finder,
		check_junit_jar_deps = deps.check_junit_jar_deps or {},
		client_provider = _client_provider,
		classpath_provider = _classpath_provider,
		binaries = _binaries,
		lsp_compiler = deps.lsp_compiler or compilers.lsp,
		build_tool_getter = deps.build_tool_getter or build_tools.get,
		method_id_resolver = _method_id_resolver,
	}
end

--- @param jar_deps neotest-java.CheckJunitJarDeps
--- @return fun(filepath: neotest-java.Path, default_version: string): neotest-java.Path
local function create_check_junit_jar(jar_deps)
	return function(filepath, default_version)
		local file_exists_fn = jar_deps.file_exists or File.exists
		local _exists, _ = file_exists_fn(filepath:to_string())
		if not _exists then
			local detector = jar_deps.version_detector or JunitVersionDetector(DEFAULT_VERSION_DETECTOR_DEPS)
			local detected_version, detected_filepath = detector.detect_existing_version()
			if detected_version and detected_filepath then
				return detected_filepath
			end
		end
		assert(
			_exists,
			([[
    Junit Platform Console Standalone jar not found at %s
    Please run the following command to download it: NeotestJava setup
    Or alternatively, download it from https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar
  ]]):format(filepath, default_version, default_version)
		)
		return filepath
	end
end

--- @param config neotest-java.ConfigOpts
--- @param deps? neotest-java.Dependencies
--- @return neotest-java.Adapter
local function NeotestJavaAdapter(config, deps)
	config = vim.tbl_extend("force", DEFAULT_CONFIG, config or {})
	local resolved = resolve_deps(deps)
	local check_junit_jar = create_check_junit_jar(resolved.check_junit_jar_deps)

	logger.info("neotest-java adapter initialized")
	logger.debug("config: " .. vim.inspect(config))

	mkdir(Path(vim.fn.stdpath("data")):append("neotest-java"))

	if not config.disable_update_notifications and not ch.update_notification_shown then
		local existing_version, _ = version_detector.detect_existing_version()
		if existing_version then
			local has_update, latest_version = version_detector.check_for_update(existing_version)
			if has_update and latest_version then
				ch.update_notification_shown = true
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
		local _root = resolved.root_finder.find_root(cwd)
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

	local spec_builder = SpecBuilder({
		classpath_provider = resolved.classpath_provider,
		binaries = resolved.binaries,
		mkdir = mkdir,
		scan = scan,
		compile = function(base_dir, compile_mode)
			resolved.lsp_compiler.compile({
				base_dir = base_dir,
				compile_mode = compile_mode,
			})
		end,
		report_folder_name_gen = report_folder_name_gen,
		build_tool_getter = resolved.build_tool_getter,
		detect_project_type = detect_project_type,
		launch_debug_test = launcher.launch_debug_test,
	})

	return setmetatable({
		install = function()
			local Installer = require("neotest-java.install")
			local installer = Installer({
				exists = File.exists,
				checksum = function(path)
					local hash, err = checksum.sha256(path:to_string())
					if not hash then
						error(err)
					end
					return hash
				end,
				download = function(url, output)
					return vim.system({ "curl", "--output", output, url, "--create-dirs" }):wait(10000)
				end,
				delete_file = vim.fn.delete,
				ask_user_consent = function(msg, choices, cb)
					vim.ui.select(choices, { prompt = msg }, function(choice)
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
			method_id_resolver = resolved.method_id_resolver,
		}).discover_positions,
		results = ResultBuilder({
			scan_dir = scan,
			junit_result_reader = JunitResultReader({
				xml_reader = XmlReader.new({ read_file = read_file }),
			}),
			remove_file = remove_file,
			tempname_fn = nio.fn.tempname,
		}).build_results,
		root = function(dir)
			return resolved.root_finder.find_root(dir)
		end,
		build_spec = function(args)
			local actual_jar = check_junit_jar(config.junit_jar, config.default_junit_jar_version.version)
			local build_config = vim.tbl_extend("force", config, { junit_jar = actual_jar })
			return spec_builder.build_spec(args, build_config)
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
