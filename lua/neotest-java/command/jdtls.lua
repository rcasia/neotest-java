local nio = require("nio")
local write_file = require("neotest-java.util.write_file")
local compatible_path = require("neotest-java.util.compatible_path")
local logger = require("neotest-java.logger")

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

---@param additional_classpath_entries string[]
M.get_classpath = function(additional_classpath_entries)
	additional_classpath_entries = additional_classpath_entries or {}

	local classpaths = {}

	local any_java_file = assert(find_any_java_file(), "No Java file found in the current directory.")
	local bufnr = preload_file_for_lsp(any_java_file)
	local uri = vim.uri_from_bufnr(bufnr)
	local runtime_classpath_future = nio.control.future()
	local test_classpath_future = nio.control.future()

	---@param future nio.control.Future
	for scope, future in pairs({ ["runtime"] = runtime_classpath_future, ["test"] = test_classpath_future }) do
		local options = vim.json.encode({ scope = scope })
		local cmd = {
			command = "java.project.getClasspaths",
			arguments = { uri, options },
		}
		-- TODO: look for a way to use vim.lsp.Client innstead of jdtls.util.execute_command
		require("jdtls.util").execute_command(cmd, function(err1, resp)
			assert(not err1, vim.inspect(err1))

			future.set(resp.classpaths)
		end, bufnr)
	end

	local runtime_classpaths = runtime_classpath_future.wait()
	local test_classpaths = test_classpath_future.wait()

	for _, v in ipairs(additional_classpath_entries) do
		classpaths[#classpaths + 1] = v
	end
	for _, v in ipairs(runtime_classpaths) do
		classpaths[#classpaths + 1] = v
	end
	for _, v in ipairs(test_classpaths) do
		classpaths[#classpaths + 1] = v
	end

	logger.debug(("classpath entries: %d"):format(#classpaths))

	return classpaths
end

M.get_classpath_file_argument = function(report_dir, additional_classpath_entries)
	local classpath = table.concat(M.get_classpath(additional_classpath_entries), ":")
	local temp_file = compatible_path(report_dir .. "/.cp")
	write_file(temp_file, ("-cp %s"):format(classpath))

	return ("@%s"):format(temp_file)
end

return M
