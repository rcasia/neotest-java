local fun = require("fun")
local compatible_path = require("neotest-java.util.compatible_path")
local read_file       = require("neotest-java.util.read_file")
local iter = fun.iter
local totable = fun.totable
local scan = require("plenary.scandir")
local run = require("neotest-java.command.run")
local binaries = require("neotest-java.command.binaries")
local File = require("neotest.lib.file")
local nio = require("nio")
local Path = require("plenary.path")
local logger = require("neotest-java.logger")

local JAVA_FILE_PATTERN = ".+%.java$"
local PROJECT_FILENAME = "build.gradle"

local function find_file_in_dir(filename, dir)
	return totable(
		--
		iter(scan.scan_dir(dir, { silent = true }))
			--
			:filter(function(path)
				return string.find(path, filename, 1, true)
			end)
	)[1]
end

local function to_gradle_path(dependency)
	if dependency == nil then
		return nil
	end
	local group_id, artifact_id, version = dependency:match("([^:]+):([^:]+):([^:]+)")

	local filename = string.format("%s-%s.jar", artifact_id, version)
	local dir = compatible_path(
		string.format(
			"%s/.gradle/caches/modules-2/files-2.1/%s/%s/%s",
			os.getenv("HOME"),
			group_id,
			artifact_id,
			version
		)
	)
	local result = find_file_in_dir(filename, dir)
	return result
end

local function take_just_the_dependency(line)
	--
	-- Example of line with a standard dependency line
	-- | +--- org.springframework.boot:spring-boot-starter:3.1.0
	-- Expected:
	-- org.springframework.boot:spring-boot-starter:3.1.0", dependency1)

	-- Example of line with a dependency line that shows a version update
	-- | +--- org.junit.platform:junit-platform-launcher:1.9.2 -> 1.9.3
	-- Expected:
	-- org.junit.platform:junit-platform-launcher:1.9.3
	--
	local dependency = line:match("[%w.-]+:[%w.-]+:[%w.-]+")
	local old_version, new_version = line:match("(%d+%.%d+%.%d+) %-+> (%d+%.%d+%.%d+)")

	if dependency and new_version then
		return string.gsub(dependency, old_version, new_version)
	end

	return dependency
end

---@class neotest-java.GradleBuildTool : neotest-java.BuildTool
local gradle = {}

gradle.source_dir = function(root)
	root = root and root or "."
	return compatible_path(root .. "/src/main/java")
end

gradle.get_output_dir = function(root)
	root = root and root or "."
	return compatible_path(root .. "/build/neotest-java")
end

gradle.get_sources = function(root)
	root = root and root or "."

	local sources = {}
	local source_directory = gradle.source_dir(root)
	if File.exists(source_directory) then
		logger.debug("Scanning sources in " .. source_directory)
		sources = scan.scan_dir(gradle.source_dir(root), {
		search_pattern = JAVA_FILE_PATTERN,
	})
	end

	local generated_sources = {}
	local generated_sources_dir = root .. "/build"
	if File.exists(generated_sources_dir) then
		generated_sources = scan.scan_dir(generated_sources_dir, {
			search_pattern = JAVA_FILE_PATTERN,
		})
	end

	for _, source in ipairs(generated_sources) do
		table.insert(sources, source)
	end

	return sources
end

gradle.get_test_sources = function(root)
	root = root and root or "."

	local test_sources = scan.scan_dir(compatible_path(root .. "/src/test/java"), {
		search_pattern = JAVA_FILE_PATTERN,
	})
	return test_sources
end

gradle.get_resources = function(root)
	root = root or "."
	return { compatible_path(root .. "/src/main/resources"), compatible_path(root .. "/src/test/resources") }
end

---@param mod neotest-java.Module
gradle.get_dependencies_classpath = function(mod)
	local output_dir = mod:get_output_dir()
	-- create dir if not exists
	nio.fn.mkdir(output_dir, "p")

	-- '< /dev/null' is necessary
	-- https://github.com/gradle/gradle/issues/15941#issuecomment-1191510921
	-- FIX: this will work only with unix systems
	local suc =
		os.execute(binaries.gradle() .. " dependencies --project-dir=".. mod.base_dir .." > "..  output_dir.."/dependencies.txt " .. "< /dev/null")
	assert(suc, "failed to run")

	local output = read_file(compatible_path(output_dir .. "/dependencies.txt"))
	local output_lines = vim.split(output, "\n")

	local jars = iter(output_lines)
		--
		:map(take_just_the_dependency)
		--
		:map(to_gradle_path)
		--
		-- filter nil
		:filter(function(x)
			return x ~= nil
		end)
		-- distinct
		:reduce(function(acc, curr)
			if not acc[curr] then
				acc[curr] = curr
			end
			return acc
		end, {})

	local result = ""
	iter(jars):foreach(function(jar)
		result = result .. ":" .. jar
	end)

	return result
end

gradle.prepare_classpath = function(output_dirs, resources, mod)
	output_dirs = output_dirs and output_dirs or {}
	resources = resources or gradle.get_resources()


	local classpath = gradle.get_dependencies_classpath(mod)

	for i, dir in ipairs(output_dirs) do
		output_dirs[i] = compatible_path(dir .. "/classes")
	end

	local classpath_arguments = ([[
		-cp %s:%s:%s
	]]):format(
		table.concat(resources, ":"),
		classpath,
		table.concat(output_dirs, ":")
	)

	--write manifest file
	local arguments_filepath
	if mod then
		arguments_filepath = compatible_path(mod:get_output_dir() .. "/cp_arguments.txt")
	else
		arguments_filepath = compatible_path("build/neotest-java/cp_arguments.txt")
	end

	nio.fn.mkdir(Path:new(arguments_filepath):parent():absolute(), "p")

		local arguments_file = io.open(arguments_filepath, "w")
		or error("Could not open file for writing: " .. arguments_filepath)
	local buffer = ""
	for i = 1, #classpath_arguments do
		buffer = buffer .. classpath_arguments:sub(i, i)
		if i % 500 == 0 then
			arguments_file:write(buffer)
			buffer = ""
		end
	end
	if buffer ~= "" then
		arguments_file:write(buffer)
	end

	arguments_file:close()
end

function gradle.get_project_filename()
	return PROJECT_FILENAME
end

---@type neotest-java.BuildTool
return gradle
