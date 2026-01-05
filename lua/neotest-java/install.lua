local exists = require("neotest.lib.file").exists
local lib = require("neotest.lib")
local logger = require("neotest-java.logger")

--- @param file_path neotest-java.Path
--- @return string hash
local checksum = function(file_path)
	local f = assert(io.open(file_path:to_string(), "rb"))
	local data = f:read("*a")
	f:close()
	local hash = vim.fn.sha256(data)
	return hash
end

--- @param config neotest-java.ConfigOpts
local install = function(config)
	local filepath = config.junit_jar:to_string()

	if exists(filepath) then
		lib.notify("Already setup!")
		return
	end
	local default_junit_jar_filepath = config.default_junit_jar_filepath:to_string()

	local out = vim.system({
		"curl",
		"--output",
		default_junit_jar_filepath,
		("https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar"):format(
			config.default_junit_jar_version.version,
			config.default_junit_jar_version.version
		),
		"--create-dirs",
	}):wait(10000)

	if out.code ~= 0 then
		lib.notify(string.format("Error while downloading: \n %s", out.stderr), "error")
		logger.error(out.stderr)
		return
	end

	local sha = checksum(config.default_junit_jar_filepath)
	local expected_sha = config.default_junit_jar_version.sha256
	if sha ~= expected_sha then
		local message = ([[
			Checksum verification failed!
			Expected: %s
			Got:      %s
		]]):format(expected_sha, sha)

		lib.notify(message, "error")
		logger.error(message)
		return
	end
	lib.notify("Downloaded Junit Standalone successfully at: \n" .. default_junit_jar_filepath)
end

return install
