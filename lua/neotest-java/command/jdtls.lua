local nio = require("nio")

M = {}

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

return M
