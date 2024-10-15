local logger = require("neotest-java.logger")
local jdtls = require("neotest-java.command.jdtls")
local compatible_path = require("neotest-java.util.compatible_path")

local binaries = {

	java = function()
		local ok, jdtls_java_home = pcall(jdtls.get_java_home)

		if ok then
			return compatible_path(jdtls_java_home .. "/bin/java")
		end

		logger.warn("Unable to detect JAVA_HOME. Using defualt binary in path: java")
		return "java"
	end,

	javac = function()
		local ok, jdtls_java_home = pcall(jdtls.get_java_home)

		if ok then
			return compatible_path(jdtls_java_home .. "/bin/javac")
		end

		logger.warn("Unable to detect JAVA_HOME. Using defualt binary in path: javac")
		return "javac"
	end,
}

return binaries
