local run = require("neotest-java.command.run")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local scan = require("plenary.scandir")
local mvn = require("neotest-java.command.binaries").mvn
local logger = require("neotest-java.logger")
local read_file = require("neotest-java.util.read_file")
local compatible_path = require("neotest-java.util.compatible_path")
local File = require("neotest.lib.file")
local write_file = require("neotest-java.util.write_file")
local fun = require("fun")
local take_just_the_dependency = require("neotest-java.util.just_take_the_dependency")
local iter = fun.iter
local totable = fun.totable

local JAVA_FILE_PATTERN = ".+%.java$"
local JAR_FILE_PATTERN = ".+%.jar$"
local PROJECT_FILE = "pom.xml"

---@class neotest-java.MavenBuildTool : neotest-java.BuildTool
local maven = {}

local function find_file_in_dir(filename, dir)
	return totable(
		--
		iter(scan.scan_dir(dir, { silent = true, search_pattern = JAR_FILE_PATTERN }))
			--
			:filter(function(path)
				return string.find(path, filename, 1, true)
			end)
	)[1]
end

local function to_maven_path(dependency)
	if dependency == nil then
		return nil
	end
	local group_id, artifact_id, version = dependency:match("([^:]+):([^:]+):([^:]+)")

	local filename = string.format("%s-%s.jar", artifact_id, version)
	local filename_fallback = string.format("%s-%s", artifact_id, version)
	local dir =
		string.format("%s/.m2/repository/%s/%s/%s", os.getenv("HOME"), group_id:gsub("%.", "/"), artifact_id, version)
	local result = find_file_in_dir(filename, dir) or find_file_in_dir(filename_fallback, dir)
	return result
end

maven.source_directory = function(root)
	root = root and root or "."

	local tag_content = read_xml_tag(PROJECT_FILE, "project.build.sourceDirectory")

	if tag_content then
		logger.debug("Found sourceDirectory in pom.xml: " .. tag_content)
		return root .. "/" .. tag_content
	end

	return compatible_path(root .. "/src/main/java")
end

maven.test_source_directory = function(root)
	root = root and root or "."

	local tag_content = read_xml_tag(PROJECT_FILE, "project.build.testSourceDirectory")

	if tag_content then
		logger.debug("Found testSourceDirectory in pom.xml: " .. tag_content)
		return root .. "/" .. tag_content
	end
	return compatible_path(root .. "/src/test/java")
end

maven.get_output_dir = function(root)
	root = root and root or "."
	-- TODO: read from pom.xml <build><directory>
	return compatible_path(root .. "/target/neotest-java")
end

maven.get_sources = function(root)
	root = root and root or "."

	local sources = {}
	local source_directory = maven.source_directory(root)
	if File.exists(source_directory) then
		logger.debug("Scanning sources in " .. source_directory)
		sources = scan.scan_dir(source_directory, {
			search_pattern = JAVA_FILE_PATTERN,
		})
	end

	local generated_sources = {}
	local generated_sources_dir = root .. "/target"
	if File.exists(generated_sources_dir) then
		logger.debug("Scanning generated sources in " .. generated_sources_dir)
		generated_sources = scan.scan_dir(generated_sources_dir, {
			search_pattern = JAVA_FILE_PATTERN,
		})
		logger.debug("Found ", #generated_sources, " generated sources")
	end

	for _, source in ipairs(generated_sources) do
		table.insert(sources, source)
	end

	return sources
end

maven.get_test_sources = function(root)
	-- TODO: read from pom.xml <testSourceDirectory>
	--
	local test_source_dir = maven.test_source_directory(root)

	local test_sources = {}
	if File.exists(test_source_dir) then
		test_sources = scan.scan_dir(test_source_dir, {
			search_pattern = JAVA_FILE_PATTERN,
		})
	end

	return test_sources
end

maven.get_resources = function(root)
	root = root or "."

	-- TODO: read from pom.xml <resources>
	return { compatible_path(root .. "/src/main/resources"), compatible_path(root .. "/src/test/resources") }
end

---@param mod neotest-java.Module
maven.get_dependencies_classpath = function(mod)
	local settings_filename = ("%s/pom.xml"):format(mod and mod.base_dir or ".")
	local command = ("%s dependency:tree -f %s"):format(mvn(), settings_filename)
	local dependency_classpath = run(command)
	assert(dependency_classpath)
	assert(dependency_classpath ~= "")

	local output = dependency_classpath
	local output_lines = vim.split(output, "\n")

	local jars = iter(output_lines)
		--
		:map(take_just_the_dependency)
		--
		-- filter nil
		:filter(function(x)
			return x ~= nil
		end)
		:map(to_maven_path)
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

	assert(result)
	assert(result ~= "")

	if mod then
		write_file(mod:get_output_dir() .. "/classpath.txt", result)
	else
		write_file("target/neotest-java/classpath.txt", result)
	end
	return result
end

---@param mod neotest-java.Module
maven.prepare_classpath = function(output_dirs, resources, mod)
	output_dirs = output_dirs and output_dirs or {}
	resources = resources or maven.get_resources()

	local classpath = maven.get_dependencies_classpath(mod)

	for i, dir in ipairs(output_dirs) do
		output_dirs[i] = compatible_path(dir .. "/classes")
	end

	-- write in file per buffer of 500 characters
	local classpath_arguments = ([[
-cp %s:%s:%s
	]]):format(table.concat(resources, ":"), classpath, table.concat(output_dirs, ":"))

	--write manifest file
	local arguments_filepath
	if mod then
		arguments_filepath = compatible_path(mod:get_output_dir() .. "/cp_arguments.txt")
	else
		arguments_filepath = compatible_path("target/neotest-java/cp_arguments.txt")
	end

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

function maven.get_project_filename()
	return PROJECT_FILE
end

---@type neotest-java.BuildTool
return maven
