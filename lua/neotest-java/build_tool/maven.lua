local run = require("neotest-java.command.run")

---@type neotest-java.BuildTool
local maven = {}

local memoized_result
---@return string
maven.get_dependencies_classpath = function()
	if memoized_result then
		return memoized_result
	end

	local command = "mvn -q dependency:build-classpath -Dmdep.outputFile=target/neotest-java/classpath.txt"
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

maven.get_output_dir = function()
	return "target/neotest-java"
end

return maven
