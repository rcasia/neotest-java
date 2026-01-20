--- @class neotest-java.MethodIdResolver
--- @field public resolve_complete_method_id fun(classname: string, method_id: string, module_dir: neotest-java.Path): string
--- @class neotest-java.MethodIdResolver.Dependencies
--- @field classpath_provider neotest-java.ClasspathProvider
--- @field command_executor neotest-java.CommandExecutor
--- @field binaries neotest-java.LspBinaries
--- @param deps neotest-java.MethodIdResolver.Dependencies
--- @return neotest-java.MethodIdResolver
local MethodIdResolver = function(deps)
	local classpaths = {}
	local javap_path
	--- @type neotest-java.MethodIdResolver
	return {
		resolve_complete_method_id = function(classname, method_id, module_dir)
			if not javap_path then
				javap_path = deps.binaries.javap(module_dir)
			end
			if not classpaths[module_dir:to_string()] then
				classpaths[module_dir:to_string()] = deps.classpath_provider.get_classpath(module_dir)
			end
			local classpath = classpaths[module_dir:to_string()]

			local result = deps.command_executor.execute_command(
				"bash",
				{ "-c", javap_path:to_string() .. " -cp '" .. classpath .. "' '" .. classname .. "'" }
			)

			assert(
				result.exit_code == 0,
				"Failed to execute javap to resolve method id. Exit code: "
					.. result.exit_code
					.. ". Stderr: "
					.. result.stderr
			)

			assert(result.stdout and result.stdout:len() > 0, "javap returned empty output when resolving method id.")

			local pattern = "%s*([%w%.$<>_]+)%s+([%w_]+)%s*%(([^)]*)%)"
			local filtered_result = vim.iter(result.stdout:gmatch(pattern))
				:map(function(return_type, name, params)
					return { return_type = return_type, name = name, params = params }
				end)
				:filter(function(entry)
					return entry.name == method_id
				end)
				:totable()

			assert(
				#filtered_result > 0,
				"Could not find method '"
					.. method_id
					.. "' in class '"
					.. classname
					.. "' via javap."
					.. " javap output:\n"
					.. result.stdout
			)

			return ("%s(%s)"):format(filtered_result[1].name, filtered_result[1].params)
		end,
	}
end
return MethodIdResolver
