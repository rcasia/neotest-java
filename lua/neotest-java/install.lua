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
	-- Require Neovim v0.12.0+ for autoinstall feature (vim.fn.sha256 requires it)
	if vim.fn.has("nvim-0.12.0") ~= 1 then
		local message = [[
			Autoinstall requires Neovim v0.12.0 or greater (currently nightly).
			The vim.fn.sha256() function used for checksum verification requires this version.
			Please manually download the JUnit JAR file or upgrade to Neovim nightly .

			Download from: https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/
		]]
		lib.notify(message, "error")
		logger.error(message)
		return
	end

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

			Removed the file at %s.
		]]):format(expected_sha, sha, default_junit_jar_filepath)

		vim.fn.delete(default_junit_jar_filepath)

		lib.notify(message, "error")
		logger.error(message)
		return
	end
	lib.notify("Downloaded Junit Standalone successfully at: \n" .. default_junit_jar_filepath)
end

return install
