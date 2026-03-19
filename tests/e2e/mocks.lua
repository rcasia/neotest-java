-- Mock dependencies for E2E testing in headless Neovim
-- This module provides mock implementations of jdtls-dependent components

local Path = require("neotest-java.model.path")

local M = {}

--- Create mock binaries that use system Java from JAVA_HOME
--- @param classpath string The classpath to use
--- @param path_separator string The platform-specific path separator (":" or ";")
--- @return table
function M.create_mocks(classpath, path_separator)
	path_separator = path_separator or ":"

	return {
		-- Mock binaries module - returns system Java
		binaries = function(deps)
			return {
				java = function(cwd)
					local java_home = vim.env.JAVA_HOME
					assert(java_home, "JAVA_HOME environment variable must be set")
					return Path(java_home):append("bin/java")
				end,
				javap = function(cwd)
					local java_home = vim.env.JAVA_HOME
					assert(java_home, "JAVA_HOME environment variable must be set")
					return Path(java_home):append("bin/javap")
				end,
			}
		end,

		-- Mock classpath provider - returns pre-resolved Maven classpath
		classpath_provider = function(deps)
			return {
				get_classpath = function(base_dir, additional_classpath_entries)
					additional_classpath_entries = additional_classpath_entries or {}
					local paths = {}

					-- Add additional classpath entries first
					for _, entry in ipairs(additional_classpath_entries) do
						table.insert(paths, entry:to_string())
					end

					-- Add the Maven-resolved classpath
					table.insert(paths, classpath)

					return table.concat(paths, path_separator)
				end,
			}
		end,

		-- Mock LSP compiler - no-op since tests are pre-compiled by Maven
		lsp_compiler = function(deps)
			return {
				compile = function(args)
					-- No-op: tests are already compiled by Maven
				end,
			}
		end,
	}
end

--- Install mocks into package.loaded
--- @param classpath string The classpath to use
--- @param path_separator string The platform-specific path separator (":" or ";")
function M.install_mocks(classpath, path_separator)
	local mocks = M.create_mocks(classpath, path_separator)

	package.loaded["neotest-java.command.binaries"] = mocks.binaries
	package.loaded["neotest-java.core.spec_builder.compiler.classpath_provider"] = mocks.classpath_provider
	package.loaded["neotest-java.core.spec_builder.compiler.lsp_compiler"] = mocks.lsp_compiler
end

return M
