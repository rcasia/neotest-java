local workspace_compiler = require("neotest-java.core.spec_builder.compiler.workspace")
local project_compiler = require("neotest-java.core.spec_builder.compiler.project")

local logger = require("neotest-java.logger")
local lib = require("neotest.lib")
local nio = require("nio")

---@class NeotestJavaCompiler.Opts
---@field cwd string
---@field compile_target string
---@field compile_mode string

--- Interface for Java compilers
---@class NeotestJavaCompiler
local NeotestJavaCompiler = {}

---@param opts NeotestJavaCompiler.Opts
function NeotestJavaCompiler.compile(opts)
	logger.debug(("buidling in %s mode"):format(opts.compile_mode))

	nio
		.run(function(_)
			nio.scheduler()
			local result = nil
			if opts.compile_target == "workspace" then
				result = workspace_compiler(opts.compile_mode)
				lib.notify("Building workspace...")
			elseif opts.compile_target == "project" then
				result = project_compiler(opts.compile_mode)
				lib.notify("Building project...")
			end

			local msg, level
			if result == 0 then
				msg = "%s compiling %s files has failed"
				level = vim.log.levels.ERROR
			elseif result == 1 then
				msg = "%s compiled %s files successfully"
				level = vim.log.levels.INFO
			elseif result == 2 then
				msg = "%s compiled %s files with errors"
				level = vim.log.levels.WARN
			else
				msg = "%s compilation of %s files has been canceled"
				level = vim.log.levels.INFO
			end
			lib.notify(string.format(msg, opts.compile_mode, opts.compile_target), level)
		end)
		:wait()

	lib.notify("Building finished...")
	logger.debug("building is complete")
end

return NeotestJavaCompiler
