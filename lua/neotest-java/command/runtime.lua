local File = require("neotest.lib.file")

local read_xml_tag = require("neotest-java.util.read_xml_tag")
local ch = require("neotest-java.context_holder")
local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

local COMPILER = "org.eclipse.jdt.core.compiler.source"
local LOCATION = "org.eclipse.jdt.ls.core.vm.location"
local RUNTIMES = {}

local function input_runtime(actual_version)
	local message =
		string.format("Enter runtime directory for JDK-%s (defaults to JAVA_HOME if empty): ", actual_version)
	local runtime_path = nio.fn.input({
		default = "",
		prompt = message,
		completion = "dir",
		cancelreturn = "__INPUT_CANCELLED__",
	})
	if runtime_path == "__INPUT_CANCELLED__" then
		log.info(string.format("Defaulting to JAVA_HOME due to empty user input for %s", actual_version))
		return vim.env.JAVA_HOME
	elseif
		not runtime_path
		or #runtime_path == 0
		or nio.fn.isdirectory(runtime_path) == 0
		or nio.fn.isdirectory(string.format("%s/bin", runtime_path)) == 0
	then
		log.warn("Invalid runtime home directory was specified, please try again")
		return input_runtime(actual_version)
	else
		log.info(string.format("Using user input %s for runtime version %s", runtime_path, actual_version))
		return runtime_path
	end
end

local function maven_runtime()
	local context = ch.get_context()
	local plugins = read_xml_tag("pom.xml", "project.build.plugins.plugin")

	for _, plugin in ipairs(plugins or {}) do
		if plugin.artifactId == "maven-compiler-plugin" and plugin.configuration then
			if plugin.configuration.target ~= plugin.configuration.source then
				error("Target and source mismatch detected in maven-compiler-plugin")
			end
			local target_version = vim.split(plugin.configuration.target, "%.")
			local actual_version = target_version[#target_version]
			if RUNTIMES[actual_version] then
				return RUNTIMES[actual_version]
			end

			local runtime_name = string.format("JAVA_HOME_%d", actual_version)
			if context and context.config.java_runtimes[runtime_name] then
				return ch.get_context().config.java_runtimes[runtime_name]
			elseif vim.env and vim.env[runtime_name] then
				return vim.env[runtime_name]
			else
				local runtime_path = input_runtime(actual_version)
				RUNTIMES[actual_version] = runtime_path
				return runtime_path
			end
		end
	end
	log.warn("Unable to resolve the runtime from maven-compiler-plugin, defaulting to JAVA_HOME")
	return vim.env.JAVA_HOME
end

local function gradle_runtime()
	-- fix: what to do here, is it needed, or does gradle pick it up from the local project config, have to check ?
	-- fix: do we need to provide explicit runtime to gradle ? thensomething has to read the gradle.properties and / or build.gradle to parse the runtime here
	log.warn("Unable to resolve the runtime from build.gradle, defaulting to JAVA_HOME")
	return vim.env.JAVA_HOME
end

local function extract_runtime(bufnr)
	local uri = vim.uri_from_bufnr(bufnr)
	local err, settings, client = lsp.execute_command({
		command = "java.project.getSettings",
		arguments = { uri, { COMPILER, LOCATION } },
	}, bufnr)

	if err ~= nil or client == nil or settings == nil then
		return
	end

	local config = client.config.settings.java or {}
	config = config.configuration or {}

	local runtimes = config.runtimes
	local location = vim.env.JAVA_HOME
	local compiler = settings[COMPILER]

	-- we can early exit with location here
	if settings[LOCATION] then
		location = settings[LOCATION]
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

	if not location or #location == 0 or nio.fn.isdirectory(location) == 0 then
		return
	end
	return location
end

---@return string | nil
local function get_runtime(opts)
	-- fix: this is not robust, there is no way to know where this is triggered from and if the current buffer is actually a 'java' one needs to be changed !!!
	local bufnr = nio.api.nvim_get_current_buf()
	local runtime = extract_runtime(bufnr)
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
		log.error("Unable to resolve project runtime")
		return nil
	end
end

return get_runtime
