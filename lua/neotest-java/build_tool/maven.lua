local run = require("neotest-java.command.run")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local scan = require("plenary.scandir")
local mvn = require("neotest-java.command.binaries").mvn
local logger = require("neotest.logging")
local read_file = require("neotest-java.util.read_file")
local compatible_path = require("neotest-java.util.compatible_path")
local File = require("neotest.lib.file")

local JAVA_FILE_PATTERN = ".+%.java$"
local PROJECT_FILE = "pom.xml"

local maven = {}

maven.source_directory = function(root)
	root = root and root or "."

	local tag_content = read_xml_tag(PROJECT_FILE, "project.build.sourceDirectory")

	if tag_content then
		logger.debug("Found sourceDirectory in pom.xml: " .. tag_content)
		return root .. "/" .. tag_content
	end

	return root .. compatible_path("src/main/java")
end

maven.test_source_directory = function(root)
	root = root and root or "."

	local tag_content = read_xml_tag(PROJECT_FILE, "project.build.testSourceDirectory")

	if tag_content then
		logger.debug("Found testSourceDirectory in pom.xml: " .. tag_content)
		return root .. "/" .. tag_content
	end
	return root .. compatible_path("src/test/java")
end

maven.get_output_dir = function(root)
	root = root and root or "."
	-- TODO: read from pom.xml <build><directory>
	return root .. compatible_path("target/neotest-java")
end

maven.get_sources = function(root)
	root = root and root or "."

	local sources = {}
	local source_directory = maven.source_directory(root)
	if File.exists(source_directory) then
		sources = scan.scan_dir(source_directory, {
			search_pattern = JAVA_FILE_PATTERN,
		})
	end

	local generated_sources = {}
	local generated_sources_dir = root .. "/target"
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

maven.get_resources = function()
	-- TODO: read from pom.xml <resources>
	return { compatible_path("src/main/resources"), compatible_path("src/test/resources") }
end

local memoized_result
---@return string
maven.get_dependencies_classpath = function()
	if memoized_result then
		return memoized_result
	end

	local classpath_filepath = compatible_path("target/neotest-java/classpath.txt")
	local command = ("%s -q dependency:build-classpath -Dmdep.outputFile=%s"):format(mvn(), classpath_filepath)
	run(command)
	local dependency_classpath = read_file(classpath_filepath)

	if string.match(dependency_classpath, "ERROR") then
		error('error while running command "' .. command .. '" -> ' .. dependency_classpath)
	end

	memoized_result = dependency_classpath
	return dependency_classpath
end

maven.prepare_classpath = function(output_dirs)
	output_dirs = output_dirs and output_dirs or {}
	local classpath = maven.get_dependencies_classpath()

	for i, dir in ipairs(output_dirs) do
		output_dirs[i] = compatible_path(dir .. "/classes")
	end

	-- write in file per buffer of 500 characters
	local classpath_arguments = ([[
-cp %s:%s:%s
	]]):format(
		table.concat(maven.get_resources(), ":"),
		classpath,
		-- maven.get_output_dir() .. "/classes",
		table.concat(output_dirs, ":")
	)

	--write manifest file
	local arguments_filepath = compatible_path("target/neotest-java/cp_arguments.txt")
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

---@type neotest-java.BuildTool
return maven
