local run = require("neotest-java.command.run")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local scan = require("plenary.scandir")
local mvn = require("neotest-java.command.binaries").mvn
local logger = require("neotest.logging")

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

maven.get_sources_glob = function()
	-- TODO: read from pom.xml <sourceDirectory>

	-- check if there are generated sources
	local generated_sources = scan.scan_dir("target", {
		search_pattern = ".+%.java",
	})
	if #generated_sources > 0 then
		return ("%s/**/*.java target/**/*.java"):format(maven.source_directory())
	end
	return ("%s/**/*.java"):format(maven.source_directory())
end

maven.get_test_sources_glob = function()
	-- TODO: read from pom.xml <testSourceDirectory>

	if tag then
		return tag
	end

	return "src/test/**/*.java"
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
