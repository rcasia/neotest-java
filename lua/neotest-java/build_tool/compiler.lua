local log = require("neotest-java.logger")
local nio = require("nio")
local Job = require("plenary.job")
local lib = require("neotest.lib")
local binaries = require("neotest-java.command.binaries")
local build_tools = require("neotest-java.build_tool")
local read_file = require("neotest-java.util.read_file")
local write_file = require("neotest-java.util.write_file")
local config = require("neotest-java.context_holder").get_context().config
local compatible_path = require("neotest-java.util.compatible_path")

local Compiler = {}

---@param sources table<string>
---@param cache_dir string
---@return table<string> changed_sources
local filter_unchanged_sources = function(sources, cache_dir)
	---@type { hash: string, source: string }
	local source_hashmap
	local success
	local cache_filepath = string.format("%s/cached_classes.json", cache_dir)

	success, source_hashmap = pcall(function()
		return nio.fn.json_decode(read_file(cache_filepath))
	end)

	if not success then
		source_hashmap = {}
	end

	local changed_sources = {}
	for _, source in ipairs(sources) do
		local hash = nio.fn.sha256(read_file(source))

		-- if file not seen yet
		-- or file content has changed
		if not source_hashmap[source] or source_hashmap[source] ~= hash then
			-- add
			source_hashmap[source] = hash

			changed_sources[#changed_sources + 1] = source
		end
	end

	log.debug("changed_sources: " .. vim.inspect(changed_sources))

	write_file(cache_filepath, nio.fn.json_encode(source_hashmap))

	return changed_sources
end

Compiler.compile_sources = function(project_type)
	local build_tool = build_tools.get(project_type)

	local sources = config.incremental_build
			and filter_unchanged_sources(build_tool.get_sources(), build_tool.get_output_dir())
		or build_tool.get_sources()

	if #sources == 0 then
		return -- skipping as there are no sources to compile
	end

	lib.notify("Compiling main sources")

	build_tool.prepare_classpath()

	local compilation_errors = {}
	local status_code = 0
	local output_dir = build_tool.get_output_dir()
	local source_compilation_command_exited = nio.control.event()
	local source_compilation_args = {
		"-g",
		"-Xlint:none",
		"-parameters",
		"-d",
		compatible_path(output_dir .. "/classes"),
		"@" .. compatible_path(output_dir .. "/cp_arguments.txt"),
	}
	for _, source in ipairs(sources) do
		table.insert(source_compilation_args, source)
	end
	Job:new({
		command = binaries.javac(),
		args = source_compilation_args,
		on_stderr = function(_, data)
			table.insert(compilation_errors, data)
		end,
		on_exit = function(_, code)
			status_code = code
			if code == 0 then
				source_compilation_command_exited.set()
			else
				source_compilation_command_exited.set()
				lib.notify("Error compiling sources", vim.log.levels.ERROR)
				log.error("test compilation error args: ", vim.inspect(source_compilation_args))
				error("Error compiling sources: " .. table.concat(compilation_errors, "\n"))
			end
		end,
	}):start()
	source_compilation_command_exited.wait()
	assert(status_code == 0, "Error compiling sources")
end

Compiler.compile_test_sources = function(project_type)
	local build_tool = build_tools.get(project_type)

	local sources = config.incremental_build
			and filter_unchanged_sources(build_tool.get_test_sources(), build_tool.get_output_dir())
		or build_tool.get_test_sources()

	if #sources == 0 then
		return -- skipping as there are no sources to compile
	end

	lib.notify("Compiling test sources")

	local compilation_errors = {}
	local status_code = 0
	local output_dir = build_tool.get_output_dir()

	local test_compilation_command_exited = nio.control.event()
	local test_sources_compilation_args = {
		"-g",
		"-Xlint:none",
		"-parameters",
		"-d",
		compatible_path(output_dir .. "/classes"),
		"@" .. compatible_path(output_dir .. "/cp_arguments.txt"),
	}
	for _, source in ipairs(sources) do
		table.insert(test_sources_compilation_args, source)
	end

	Job:new({
		command = binaries.javac(),
		args = test_sources_compilation_args,
		on_stderr = function(_, data)
			table.insert(compilation_errors, data)
		end,
		on_exit = function(_, code)
			status_code = code
			test_compilation_command_exited.set()
			if code ~= 0 then
				lib.notify("Error compiling test sources", vim.log.levels.ERROR)
				log.error("test compilation error args: ", vim.inspect(test_sources_compilation_args))
				error("Error compiling test sources: " .. table.concat(compilation_errors, "\n"))
			end
		end,
	}):start()
	test_compilation_command_exited.wait()
	assert(status_code == 0, "Error compiling test sources")
end

return Compiler
