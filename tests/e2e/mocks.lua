-- Mock dependencies for E2E testing in headless Neovim
-- This module provides mock implementations of LSP-dependent components
-- All production code runs as-is, only the LSP client provider is mocked

local M = {}

--- Install mocks into package.loaded
--- @param classpath string The classpath to use
function M.install_mocks(classpath)
	-- Detect Windows for path separator
	local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
	local path_sep = is_windows and ";" or ":"

	-- Mock the client_provider module - factory that returns a function(cwd) -> fake client
	package.loaded["neotest-java.core.spec_builder.compiler.client_provider"] = function(_deps)
		return function(_cwd)
			return {
				request = function(_, method, params, callback)
					if method == "workspace/executeCommand" and params.command == "java.project.getSettings" then
						-- Return Java home from environment
						local java_home = vim.env.JAVA_HOME
						assert(java_home, "JAVA_HOME environment variable must be set")
						callback(nil, { ["org.eclipse.jdt.ls.core.vm.location"] = java_home })
					end
				end,
			}
		end
	end

	-- Mock classpath provider - returns pre-resolved Maven classpath
	package.loaded["neotest-java.core.spec_builder.compiler.classpath_provider"] = function(_)
		return {
			get_classpath = function(_, additional_classpath_entries)
				additional_classpath_entries = additional_classpath_entries or {}
				local paths = {}

				-- Add additional classpath entries first
				for _, entry in ipairs(additional_classpath_entries) do
					table.insert(paths, entry:to_string())
				end

				-- Add the Maven-resolved classpath
				table.insert(paths, classpath)

				return table.concat(paths, path_sep)
			end,
		}
	end

	-- Mock LSP compiler - no-op since tests are pre-compiled by Maven
	package.loaded["neotest-java.core.spec_builder.compiler.lsp_compiler"] = function(_)
		return {
			compile = function(_)
				-- No-op: tests are already compiled by Maven
			end,
		}
	end
end

return M
