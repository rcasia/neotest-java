local Path = require("neotest-java.model.path")

--- @class MethodIdResolver
--- @field public resolve_complete_method_id fun(classname: string, method_id: string): string

--- @class MethodIdResolver.Dependencies
--- @field classpath_provider neotest-java.ClasspathProvider
--- @field command_executor neotest-java.CommandExecutor
--- @field binaries neotest-java.LspBinaries

--- @param deps MethodIdResolver.Dependencies
--- @return MethodIdResolver
local MethodIdResolver = function(deps)
	-- TODO: Should take module dir as parameter
	local module_dir = Path("my_module_dir")
	local javap_path = deps.binaries.javap(module_dir)
	--- @type MethodIdResolver
	return {
		resolve_complete_method_id = function(classname, method_id)
			local classpath = deps.classpath_provider.get_classpath(module_dir)

			local result = deps.command_executor.execute_command(
				"bash",
				{ "-c", javap_path:to_string(), "-cp=" .. classpath, classname }
			)

			local pattern = "%s*([%w%.$<>_]+)%s+([%w_]+)%s*%(([^)]*)%)"
			local filtered_result = vim.iter(result.stdout:gmatch(pattern))
				:map(function(return_type, name, params)
					return { return_type = return_type, name = name, params = params }
				end)
				:filter(function(entry)
					return entry.name == method_id
				end)
				:totable()

			return ("%s(%s)"):format(filtered_result[1].name, filtered_result[1].params)
		end,
	}
end

return MethodIdResolver
