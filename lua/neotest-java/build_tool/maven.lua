local run = require("neotest-java.command.run")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local scan = require("plenary.scandir")
local mvn = require("neotest-java.command.binaries").mvn
local logger = require("neotest.logging")
local read_file = require("neotest-java.util.read_file")
local compatible_path = require("neotest-java.util.compatible_path")

local JAVA_FILE_PATTERN = ".+%.java$"

local maven = {}

maven.source_directory = function()
	local tag_content = read_xml_tag("pom.xml", "project.build.sourceDirectory")

	if tag_content then
		logger.debug("Found sourceDirectory in pom.xml: " .. tag_content)
		return tag_content
	end

	return compatible_path("src/main/java")
end

maven.test_source_directory = function()
	local tag_content = read_xml_tag("pom.xml", "project.build.testSourceDirectory")
	if tag_content then
		logger.debug("Found testSourceDirectory in pom.xml: " .. tag_content)
		return tag_content
	end
	return compatible_path("src/test/java")
end

maven.get_output_dir = function()
	-- TODO: read from pom.xml <build><directory>
	return compatible_path("target/neotest-java")
end

maven.get_sources = function()
	local sources = scan.scan_dir(maven.source_directory(), {
		search_pattern = JAVA_FILE_PATTERN,
	})

	local generated_sources = scan.scan_dir("target", {
		search_pattern = JAVA_FILE_PATTERN,
	})

	for _, source in ipairs(generated_sources) do
		table.insert(sources, source)
	end

	return sources
end

maven.get_test_sources = function()
	-- TODO: read from pom.xml <testSourceDirectory>

	local test_sources = scan.scan_dir(maven.test_source_directory(), {
		search_pattern = JAVA_FILE_PATTERN,
	})

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

maven.prepare_classpath = function()
	local classpath = maven.get_dependencies_classpath()

	-- write in file per buffer of 500 characters
	local classpath_arguments = ([[
-cp %s:%s:%s
	]]):format(
		table.concat(maven.get_resources(), ":"),
		classpath,
		compatible_path(maven.get_output_dir() .. "/classes")
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
