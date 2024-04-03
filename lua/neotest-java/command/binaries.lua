local File = require("neotest.lib.file")

local binaries = {

	java = function()
		return "java"
	end,

	javac = function()
		return "javac"
	end,

	mvn = function()
		if File.exists("mvnw") then
			return "./mvnw"
		end
		return "mvn"
	end,

	gradle = function()
		if File.exists("gradlew") then
			return "./gradlew"
		end
		return "gradle"
	end,
}

return binaries
