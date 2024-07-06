local File = require("neotest.lib.file")

local read_xml_tag = require("neotest-java.util.read_xml_tag")
local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

local COMPILER = "org.eclipse.jdt.core.compiler.source"
local LOCATION = "org.eclipse.jdt.ls.core.vm.location"
local RUNTIMES = {}

local function extract_runtime(bufnr)
	local uri = vim.uri_from_bufnr(bufnr)
	local error, settings, client = nil, nil, nil
	--    lsp.execute_command({
	-- 	command = "java.project.getSettings",
	-- 	arguments = { uri, { COMPILER, LOCATION } },
	-- }, bufnr)

	if error ~= nil or client == nil then
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

	if location and nio.fn.isdirectory(location) == 0 then
		log.error(string.format("Invalid java runtime path location %s", location))
		return
	end
	return location
end

---@return string | nil
local function get_runtime(opts)
	-- todo: this is not robust, there is no way to know where this is triggered from and if the current buffer is actually a 'java' one needs to be changed !!!
	local bufnr = nio.api.nvim_get_current_buf()
	local runtime = extract_runtime(bufnr)
	if runtime and #runtime > 0 then
		return runtime
	end

	if File.exists("pom.xml") then
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
				if vim.env and vim.env[runtime_name] then
					return vim.env[runtime_name]
				else
					local message = string.format(
						"Enter runtime directory for JDK-%s (defaults to JAVA_HOME if empty): ",
						actual_version
					)
					local runtime_path = nio.fn.input({
						default = "",
						prompt = message,
						completion = "dir",
						cancelreturn = "__INPUT_CANCELLED__",
					})
					if not runtime_path or runtime_path == "__INPUT_CANCELLED__" then
						return vim.env.JAVA_HOME
					end
					RUNTIMES[actual_version] = runtime_path
					return runtime_path
				end
			end
		end
	elseif File.exists("build.gradle") then
		-- fix: what to do here, is it needed, or does gradle pick it up from the local project config, have to check ?
		return nil
	end
	log.error("Unable to extract a valid project runtime")
	return nil
end

return get_runtime
