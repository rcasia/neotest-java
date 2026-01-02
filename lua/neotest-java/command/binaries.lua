local jdtls = require("neotest-java.command.jdtls")
local logger = require("neotest-java.logger")
local Path = require("neotest-java.model.path")

local binaries = {

	java = function()
		local ok, jdtls_java_home = pcall(jdtls.get_java_home)

		if ok then
			return Path(jdtls_java_home):append("/bin/java"):to_string()
		end

		logger.warn("JAVA_HOME setting not found in jdtls. Using defualt binary: java")
		return "java"
	end,

	javac = function()
		local ok, jdtls_java_home = pcall(jdtls.get_java_home)

		if ok then
			return Path(jdtls_java_home):append("/bin/javac"):to_string()
		end

		logger.warn("JAVA_HOME setting not found in jdtls. Using default: javac")
		return "javac"
	end,
}

return binaries
