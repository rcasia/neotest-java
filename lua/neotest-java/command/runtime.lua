local File = require("neotest.lib.file")

local read_xml_tag = require("neotest-java.util.read_xml_tag")
local context_holder = require("neotest-java.context_holder")

local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

local COMPILER = "org.eclipse.jdt.core.compiler.source"
local LOCATION = "org.eclipse.jdt.ls.core.vm.location"
local RUNTIMES = {}

local function has_env(var)
	return nio.fn.getenv(var) ~= vim.NIL
end

local function get_env(var)
	return nio.fn.getenv(var)
end

local function get_java_home()
	return get_env("JAVA_HOME")
end

local function input_runtime(actual_version)
	local message =
		string.format("Enter runtime home directory for JDK-%s (default to JAVA_HOME if empty): ", actual_version)
	local runtime_path = nio.fn.input({
		default = "",
		prompt = message,
		completion = "dir",
		cancelreturn = "__INPUT_CANCELLED__",
	})
	if runtime_path == "__INPUT_CANCELLED__" then
		log.info(string.format("Defaulting to JAVA_HOME due to empty user input for %s", actual_version))
		return get_java_home()
	elseif
		not runtime_path
		or #runtime_path == 0
		or nio.fn.isdirectory(runtime_path) == 0
		or nio.fn.isdirectory(string.format("%s/bin", runtime_path)) == 0
	then
		log.warn(string.format("Invalid runtime home directory %s was specified, please try again", runtime_path))
		return input_runtime(actual_version)
	else
		log.info(string.format("Using user input %s for runtime version %s", runtime_path, actual_version))
		return runtime_path
	end
end

local function maven_runtime()
	local context = context_holder.get_context()
	local plugins = read_xml_tag("pom.xml", "project.build.plugins.plugin")

	for _, plugin in ipairs(plugins or {}) do
		if plugin.artifactId == "maven-compiler-plugin" and plugin.configuration then
			assert(
				plugin.configuration.target == plugin.configuration.source,
				"Target and source mismatch detected in maven-compiler-plugin"
			)

			local target_version = vim.split(plugin.configuration.target, "%.")
			local actual_version = #target_version > 0 and target_version[#target_version]
			if RUNTIMES[actual_version] then
				return RUNTIMES[actual_version]
			end

			local runtime_name = string.format("JAVA_HOME_%d", actual_version)
			if context and context.config.java_runtimes[runtime_name] then
				return context.config.java_runtimes[runtime_name]
			elseif has_env(runtime_name) then
				return get_env(runtime_name)
			elseif actual_version ~= nil then
				local runtime_path = input_runtime(actual_version)
				RUNTIMES[actual_version] = runtime_path
				return runtime_path
			else
				log.warn("Detected maven-compiler-plugin, but unable to resolve runtime version")
				break
			end
		end
	end

	log.warn("Unable to resolve the runtime from maven-compiler-plugin, defaulting to JAVA_HOME")
	return get_java_home()
end

local function gradle_runtime()
	-- fix: the build.gradle has to be read to obtain information about the project's configured runtime
	log.warn("Unable to resolve the runtime from build.gradle, defaulting to JAVA_HOME")
	return get_java_home()
end

local function extract_runtime(bufnr)
	local uri = vim.uri_from_bufnr(bufnr)
	local err, result, settings = lsp.execute_command("workspace/executeCommand", {
		command = "java.project.getSettings",
		arguments = { uri, { COMPILER, LOCATION } },
	}, bufnr)

	if err ~= nil or result == nil or settings == nil then
		log.warn("Unable to extract runtime from lsp client")
		return
	end
	-- used to obtain the current language server or workspace folder configuration for the the java runtimes and their locations
	local config = settings.configuration or {}

	-- location starts off being nil, we require strict matching, otherwise the runtime resolve will fallback to maven or gradle, we
	-- do not want to resolve to JAVA_HOME immediately here, it is too early.
	local location = nil
	local runtimes = config.runtimes
	local compiler = result[COMPILER]

	-- we can early exit with location here, when the location exists, however that might not always be, therefore if no location is
	-- present we try to resolve which is the default runtime configured for the project based on the language server or workspace,
	-- that is a last resort option, but still provides a valid way to resolve the runtime if all else fails
	-- settings
	if result[LOCATION] then
		location = result[LOCATION]
	else
		-- go over available runtimes and resolve it
		for _, runtime in ipairs(runtimes or {}) do
			-- default runtimes get priority
			if runtime.default == true then
				location = runtime.path
				break
			end
			-- match runtime against compliance version
			local match = runtime.name:match(".*-(.*)")
			if match and match == compiler then
				location = runtime.path
				break
			end
		end
	end

	-- location has to be strictly resolved from the project `settings` or from the runtimes in client's settings, and has to point
	-- to a valid directory on the filesystem, otherwise we return `nil` for runtime
	if not location or #location == 0 or nio.fn.isdirectory(location) == 0 then
		return nil
	end
	return location
end

---@return string | nil
local function get_runtime()
	local bufnr = nio.api.nvim_get_current_buf()
	local runtime = extract_runtime(bufnr)

	-- in case the runtime was not found, try to fetch one from the build
	-- system which the current project is using, match against maven or gradle
	-- and try to find the configured runtime, or fallback to JAVA_HOME
	if not runtime or #runtime == 0 then
		if File.exists("pom.xml") then
			runtime = maven_runtime()
		elseif File.exists("build.gradle") then
			runtime = gradle_runtime()
		end
	end

	if runtime and #runtime > 0 then
		log.info(string.format("Resolved project runtime %s", runtime))
		return runtime
	else
		log.warn("Unable to resolve the project's runtime")
		return nil
	end
end

return get_runtime
