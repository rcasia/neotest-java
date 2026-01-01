local logger = require("neotest-java.logger")

--- @class ClasspathProvider
--- @field get_classpath fun(base_dir: neotest-java.Path, additional_classpath_entries?: string[]): string

--- @class GetClasspathResponse
--- @field classpaths string[]
--- @field modulepaths string []
--- @field projectRoot string

--- @param deps { client_provider: fun(cwd: neotest-java.Path): vim.lsp.Client }
local function ClasspathProvider(deps)
	return {
		get_classpath = function(base_dir, additional_classpath_entries)
			additional_classpath_entries = additional_classpath_entries or {}

			local bufnr = vim.api.nvim_get_current_buf()
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			local buffer_uri = vim.uri_from_fname(bufname)

			local client = deps.client_provider(base_dir)

			local response_for_runtime = client:request_sync("workspace/executeCommand", {
				command = "java.project.getClasspaths",
				arguments = { buffer_uri, vim.json.encode({ scope = "runtime" }) },
			})
			logger.debug("response for runtime: " .. vim.inspect(response_for_runtime))

			local response_for_test = client:request_sync("workspace/executeCommand", {
				command = "java.project.getClasspaths",
				arguments = { buffer_uri, vim.json.encode({ scope = "test" }) },
			})

			return vim.iter({
				assert(response_for_runtime).result.classpaths,
				assert(response_for_test).result.classpaths,
				additional_classpath_entries,
			})
				:flatten()
				:join(":")
		end,
	}
end

return ClasspathProvider
