local exists = require("neotest.lib.file").exists
local lib = require("neotest.lib")
local logger = require("neotest-java.logger")

--- @param config neotest-java.ConfigOpts
local install = function(config)
	local filepath = config.junit_jar:to_string()

	if exists(filepath) then
		lib.notify("Already setup!")
		return
	end

	vim.system(
		{
			"curl",
			"--output",
			config.default_junit_jar_filepath:to_string(),
			("https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar"):format(
				config.default_version,
				config.default_version
			),
			"--create-dirs",
		},
		nil,
		function(out)
			if out.code == 0 then
				lib.notify("Downloaded Junit Standalone successfully!")
			else
				lib.notify(string.format("Error while downloading: \n %s", out.stderr), "error")
				logger.error(out.stderr)
			end
		end
	)
end

return install
