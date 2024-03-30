---@class neotest-java.BuildTool
local maven = {}

local memoized_result
---@return string
maven.get_dependencies_classpath = function()
	if memoized_result then
		return memoized_result
	end

	local command = "mvn -q dependency:build-classpath -Dmdep.outputFile=/dev/stdout"
	local handle = io.popen(command) or error()
	local dependency_classpath = handle:read("*a")
	handle:close()

	if string.match(dependency_classpath, "ERROR") then
		-- error('error while running command "' .. command .. '" -> ' .. dependency_classpath)
		dependency_classpath = ""
	end

	memoized_result = dependency_classpath
	return dependency_classpath
end

return maven
