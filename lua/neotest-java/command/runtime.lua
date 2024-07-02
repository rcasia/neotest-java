local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

local COMPILER = "org.eclipse.jdt.core.compiler.source"
local LOCATION = "org.eclipse.jdt.ls.core.vm.location"

local function extract_runtime(bufnr)
	local uri = vim.uri_from_bufnr(bufnr)
	local error, settings, client = lsp.execute_command({
		command = "java.project.getSettings",
		arguments = { uri, { COMPILER, LOCATION } },
	}, bufnr)

	if error ~= nil then
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
	log.error("Unable to extract project runtime")
	return nil
end

return get_runtime
