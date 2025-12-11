local compiler = require("neotest-java.core.spec_builder.compiler.jdtls")
local logger = require("neotest-java.logger")
local lib = require("neotest.lib")

--- Interface for Java compilers
---@class NeotestJavaCompiler
local NeotestJavaCompiler = {}

---@class NeotestJavaCompiler.Opts
---@field cwd string
---@field compile_target string
---@field compile_mode string
function NeotestJavaCompiler.compile(opts)
	logger.debug(("%s build started"):format(opts.compile_mode))
	local result, project = nil, nil
	if opts.compile_target == "workspace" then
		result, project = compiler.build_workspace(opts)
	elseif opts.compile_target == "project" then
		result, project = compiler.build_project(opts)
	end
	logger.debug("build has finished")

	local msg, level
	if result == 0 then
		msg = "Using %s compiling %s has failed"
		level = vim.log.levels.ERROR
		result = false
	elseif result == 1 then
		msg = "Using %s compiled %s successfully"
		level = vim.log.levels.INFO
		result = true
	elseif result == 2 then
		msg = "Using %s compiled %s with errors"
		level = vim.log.levels.WARN
		result = false
	else
		msg = "Using %s compilation of %s has been canceled"
		level = vim.log.levels.INFO
		result = false
	end
	lib.notify(string.format(msg, opts.compile_mode, project), level)
	return result, project
end

return NeotestJavaCompiler
