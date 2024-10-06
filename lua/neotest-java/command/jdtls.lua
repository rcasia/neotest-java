local nio = require("nio")
local write_file = require("neotest-java.util.write_file")
local compatible_path = require("neotest-java.util.compatible_path")

local M = {}

M.get_java_home = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local uri = vim.uri_from_bufnr(bufnr)
	local future = nio.control.future()

	local setting = "org.eclipse.jdt.ls.core.vm.location"
	local cmd = {
		command = "java.project.getSettings",
		arguments = { uri, { setting } },
	}
	require("jdtls.util").execute_command(cmd, function(err1, resp)
		assert(not err1, vim.inspect(err1))

		print(vim.inspect(resp))
		future.set(resp)
	end, bufnr)

	local java_exec = future.wait()

	return java_exec[setting]
end

M.get_classpath = function()
	local bufnr = vim.api.nvim_get_current_buf()
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
		require("jdtls.util").execute_command(cmd, function(err1, resp)
			assert(not err1, vim.inspect(err1))

			future.set(resp.classpaths)
		end, bufnr)
	end
	local runtime_classpaths = runtime_classpath_future.wait()
	local test_classpaths = test_classpath_future.wait()

	for _, v in ipairs(test_classpaths) do
		runtime_classpaths[#runtime_classpaths + 1] = v
	end

	return runtime_classpaths
end

M.get_classpath_file_argument = function(report_dir)
	local classpath = table.concat(M.get_classpath(), ":")
	local temp_file = compatible_path(report_dir .. "/.cp")
	write_file(temp_file, ("-cp %s"):format(classpath))

	return ("@%s"):format(temp_file)
end

return M
