local File = require("neotest.lib.file")
local ch = require("neotest-java.context_holder")

local binaries = {

	java = function()
		return "java"
	end,

	javac = function()
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
