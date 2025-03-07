local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

---@param additional_classpath_entries string[]
---@return string[]
local function get_classpaths(additional_classpath_entries)
	additional_classpath_entries = additional_classpath_entries or {}
	local bufnr = nio.api.nvim_get_current_buf()
	local uri = vim.uri_from_bufnr(bufnr)
	local result_classpaths = {}

	for _, v in ipairs(additional_classpath_entries) do
		table.insert(result_classpaths, v)
	end

	for _, scope in ipairs({ "runtime", "test" }) do
		local options = vim.json.encode({ scope = scope })
		local err, result = lsp.execute_command("workspace/executeCommand", {
			command = "java.project.getClasspaths",
			arguments = { uri, options },
		}, bufnr)
		if result == nil or err ~= nil then
			log.warn(string.format("Unable to resolve [%s] target classpahts", scope))
		else
			for _, v in ipairs(result.classpaths or {}) do
				table.insert(result_classpaths, v)
			end
		end
	end

	return result_classpaths
end

return get_classpaths
