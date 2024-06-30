local File = require("neotest.lib.file")
local runtime = require("neotest-java.command.runtime")

local binaries = {
	java = function()
		local runtime_path = runtime()
		return runtime_path and vim.fs.normalize(string.format("%s/bin/java", runtime_path)) or "java"
	end,

	javac = function()
		local runtime_path = runtime()
		return runtime_path and vim.fs.normalize(string.format("%s/bin/javac", runtime_path)) or "javac"
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
