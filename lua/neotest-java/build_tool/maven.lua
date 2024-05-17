local run = require("neotest-java.command.run")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local scan = require("plenary.scandir")
local mvn = require("neotest-java.command.binaries").mvn
local logger = require("neotest.logging")

local JAVA_FILE_PATTERN = ".+%.java$"

---@type neotest-java.BuildTool
local maven = {}

maven.source_directory = function()
	local tag_content = read_xml_tag("pom.xml", "project.build.sourceDirectory")

	if tag_content then
		logger.debug("Found sourceDirectory in pom.xml: " .. tag_content)
		return tag_content
	end

	return "src/main/java"
end

maven.test_source_directory = function()
	local tag_content = read_xml_tag("pom.xml", "project.build.testSourceDirectory")
	if tag_content then
		logger.debug("Found testSourceDirectory in pom.xml: " .. tag_content)
		return tag_content
	end
	return "src/test/java"
end

maven.get_output_dir = function()
	-- TODO: read from pom.xml <build><directory>
	return "target/neotest-java"
end

maven.get_sources = function()
	local sources = scan.scan_dir(maven.source_directory(), {
		search_pattern = JAVA_FILE_PATTERN,
	})

	local generated_sources = scan.scan_dir("target", {
		search_pattern = JAVA_FILE_PATTERN,
	})

	-- combine sources and generated sources
	local sources_str = table.concat(sources, " ")
	local generated_sources_str = table.concat(generated_sources, " ")

	return table.concat({ sources_str, generated_sources_str }, " ")
end

maven.get_test_sources = function()
	-- TODO: read from pom.xml <testSourceDirectory>

	local test_sources = scan.scan_dir(maven.test_source_directory(), {
		search_pattern = JAVA_FILE_PATTERN,
	})

	return table.concat(test_sources, " ")
end

maven.get_resources = function()
	-- TODO: read from pom.xml <resources>
	return { "src/main/resources", "src/test/resources" }
end

local memoized_result
---@return string
maven.get_dependencies_classpath = function()
	if memoized_result then
		return memoized_result
	end

	local command = mvn() .. " -q dependency:build-classpath -Dmdep.outputFile=target/neotest-java/classpath.txt"
	run(command)
	local dependency_classpath = run("cat target/neotest-java/classpath.txt")

	if string.match(dependency_classpath, "ERROR") then
		error('error while running command "' .. command .. '" -> ' .. dependency_classpath)
	end

	memoized_result = dependency_classpath
	return dependency_classpath
end

maven.write_classpath = function(filepath)
	local classpath = maven.get_dependencies_classpath()

	-- create folder if not exists
	run("mkdir -p " .. filepath:match("(.+)/[^/]+"))

	-- remeve file if exists
	run("rm -f " .. filepath)

	-- write in file per buffer of 500 characters
	local file = io.open(filepath, "w") or error("Could not open file for writing: " .. filepath)
	local buffer = ""
	for i = 1, #classpath do
		buffer = buffer .. classpath:sub(i, i)
		if i % 500 == 0 then
			file:write(buffer)
			buffer = ""
		end
	end
	-- write the remaining buffer
	if buffer ~= "" then
		file:write(buffer)
	end

	file:close()
end

return maven
