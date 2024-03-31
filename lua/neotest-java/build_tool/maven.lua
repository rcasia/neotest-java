local iter = require("fun").iter

---@type neotest-java.BuildTool
local maven = {}

local memoized_result
---@return string
maven.get_dependencies_classpath = function()
	if memoized_result then
		return memoized_result
	end

	local command = "mvn -q dependency:build-classpath -Dmdep.outputFile=/dev/stdout"
	local handle = io.popen(command) or error("error while running command " .. command)
	local dependency_classpath = handle:read("*a")
	handle:close()

	if string.match(dependency_classpath, "ERROR") then
		error('error while running command "' .. command .. '" -> ' .. dependency_classpath)
	end

	memoized_result = dependency_classpath
	return dependency_classpath
end

maven.write_classpath = function(filepath)
	local classpath = maven.get_dependencies_classpath()

	-- create folder if not exists
	os.execute("mkdir -p " .. filepath:match("(.+)/[^/]+"))

	-- write in file per buffer of 500 characters
	local buffer = ""
	for i = 1, #classpath do
		buffer = buffer .. classpath:sub(i, i)
		if i % 500 == 0 then
			os.execute("echo -n " .. buffer .. " >> " .. filepath)
			buffer = ""
		end
	end
	-- write the remaining buffer
	if buffer ~= "" then
		os.execute("echo -n " .. buffer .. " >> " .. filepath)
	end
end

maven.get_output_dir = function()
	return "target/neotest-java"
end

return maven
