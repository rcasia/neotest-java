local nio = require("nio")

local M = {}

--- @param dir? string
--- @return string | nil
local function find_any_java_file(dir)
	return assert(
		vim.iter(nio.fn.globpath(dir or ".", "**/*.java", false, true)):next(),
		"No Java file found in the current directory."
	)
end

--- @param path string
--- @return number bufnr
local function preload_file_for_lsp(path)
	assert(path, "path cannot be nil")
	local buf = vim.fn.bufadd(path) -- allocates buffer ID
	vim.fn.bufload(path) -- preload lines

	return buf
end

M.get_java_home = function()
	local any_java_file = assert(find_any_java_file(), "No Java file found in the current directory.")
	local bufnr = preload_file_for_lsp(any_java_file)
	local uri = vim.uri_from_bufnr(bufnr)
	local future = nio.control.future()

	local setting = "org.eclipse.jdt.ls.core.vm.location"
	local cmd = {
		command = "java.project.getSettings",
		arguments = { uri, { setting } },
	}
	require("jdtls.util").execute_command(cmd, function(err1, resp)
		assert(not err1, vim.inspect(err1))
		future.set(resp)
	end, bufnr)

	local java_exec = future.wait()

	return java_exec[setting]
end

return M
