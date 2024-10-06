local File = require("neotest.lib.file")
local ch = require("neotest-java.context_holder")
local jdtls = require("neotest-java.command.jdtls")
local compatible_path = require("neotest-java.util.compatible_path")
local logger = require("neotest-java.logger")

local binaries = {

	java = function()
		local ok, jdtls_java_home = pcall(jdtls.get_java_home)

		if ok then
			return compatible_path(jdtls_java_home .. "/bin/java")
		end

		logger.warn("JAVA_HOME setting not found in jdtls. Using defualt binary: java")
		return "java"
	end,

	javac = function()
		local ok, jdtls_java_home = pcall(jdtls.get_java_home)

		if ok then
			return compatible_path(jdtls_java_home .. "/bin/javac")
		end

		logger.warn("JAVA_HOME setting not found in jdtls. Using default: javac")
		return "javac"
	end,

	mvn = function()
		if File.exists("mvnw") and not ch.get_context().config.ignore_wrapper then
			return "./mvnw"
		end
		return "mvn"
	end,

	gradle = function()
		if File.exists("gradlew") and not ch.get_context().config.ignore_wrapper then
			return "./gradlew"
		end
		return "gradle"
	end,
}

return binaries
