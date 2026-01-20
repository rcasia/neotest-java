local nio = require("nio")

--- @class neotest-java.ClasspathProvider
--- @field get_classpath async fun(base_dir: neotest-java.Path, additional_classpath_entries?: neotest-java.Path[]): string classpaths joined by ":"

--- @class GetClasspathResponse
--- @field classpaths string[]
--- @field modulepaths string []
--- @field projectRoot string

--- @param deps { client_provider: fun(cwd: neotest-java.Path): vim.lsp.Client }
--- @return neotest-java.ClasspathProvider
local function ClasspathProvider(deps)
	return {
		get_classpath = function(base_dir, additional_classpath_entries)
			additional_classpath_entries = additional_classpath_entries or {}

			local base_dir_uri = vim.uri_from_fname(base_dir:to_string())
			local client = deps.client_provider(base_dir)

			local bufnr = vim.tbl_keys(client.attached_buffers)[1]
			local runtime = nio.control.future()
			local test = nio.control.future()
			vim.schedule(function()
				client:request("workspace/executeCommand", {
					command = "java.project.getClasspaths",
					arguments = { base_dir_uri, vim.json.encode({ scope = "runtime" }) },
				}, function(err, result)
					if err then
						runtime.set_error(err)
					else
						runtime.set(result.classpaths)
					end
				end, bufnr)

				client:request("workspace/executeCommand", {
					command = "java.project.getClasspaths",
					arguments = { base_dir_uri, vim.json.encode({ scope = "test" }) },
				}, function(err, result)
					if err then
						test.set_error(err)
					else
						test.set(result.classpaths)
					end
				end, bufnr)
			end)

			local additional_classpath_entries_strings = vim
				--
				.iter(additional_classpath_entries)
				--- @param path neotest-java.Path
				:map(function(path)
					return path:to_string()
				end)
				:totable()

			return vim.iter({
				runtime.wait(),
				test.wait(),
				additional_classpath_entries_strings,
			})
				:flatten()
				:join(":")
		end,
	}
end

return ClasspathProvider
