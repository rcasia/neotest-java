local File = require("neotest.lib.file")
local ch = require("neotest-java.context_holder")
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
