local logger = require("neotest-java.logger")
local version_detector = require("neotest-java.util.junit_version_detector")

---@class neotest-java.InstallDeps
---@field exists fun(filepath: string): boolean
---@field checksum fun(file_path: neotest-java.Path): string
---@field download fun(url: string, output: string): { code: number, stderr: string }
---@field delete_file fun(filepath: string): void
---@field ask_user_consent fun(message: string, choices: string[], callback: fun(choice: string | nil)): void
---@field notify fun(message: string, level?: string): void
---@field detect_existing_version fun(deps?: neotest-java.JunitVersionDetectorDeps): neotest-java.JunitVersion | nil, neotest-java.Path | nil

---@class neotest-java.Installer
---@field install fun(config: neotest-java.ConfigOpts): void

--- @param deps neotest-java.InstallDeps
--- @return neotest-java.Installer
local Installer = function(deps)
	--- @type neotest-java.InstallDeps
	local exists_fn = deps.exists
	local checksum_fn = deps.checksum
	local delete_file_fn = deps.delete_file
	local notify_fn = deps.notify
	local detect_existing_version_fn = deps.detect_existing_version
	local download_fn = deps.download
	local ask_user_consent_fn = deps.ask_user_consent

	--- Download JUnit jar for a specific version
	--- @param version_info neotest-java.JunitVersion
	--- @param target_filepath neotest-java.Path
	--- @return boolean success
	local function download_junit_jar(version_info, target_filepath)
		local url = ("https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar"):format(
			version_info.version,
			version_info.version
		)

		local target_filepath_str = target_filepath:to_string()
		local out = download_fn(url, target_filepath_str)

		if out.code ~= 0 then
			notify_fn(string.format("Error while downloading: \n %s", out.stderr), "error")
			logger.error(out.stderr)
			return false
		end

		local sha = checksum_fn(target_filepath)
		local expected_sha = version_info.sha256
		if sha ~= expected_sha then
			local message = ([[
				Checksum verification failed!
				Expected: %s
				Got:      %s

				Removed the file at %s.
			]]):format(expected_sha, sha, target_filepath_str)

			delete_file_fn(target_filepath_str)

			notify_fn(message, "error")
			logger.error(message)
			return false
		end

		return true
	end

	return {
		--- @param config neotest-java.ConfigOpts
		install = function(config)
			local filepath = config.junit_jar
			local default_junit_jar_filepath = config.default_junit_jar_filepath
			local filepath_str = filepath:to_string()

			-- Check if already installed with latest version
			if exists_fn(filepath_str) then
				-- Verify it's the correct version by checksum
				local current_sha = checksum_fn(filepath)
				if current_sha == config.default_junit_jar_version.sha256 then
					notify_fn("JUnit jar is already set up with the latest version!")
					return
				end
			end

			-- Detect existing version
			local existing_version, existing_filepath = detect_existing_version_fn()
			local has_update, latest_version = false, nil

			if existing_version then
				has_update, latest_version = version_detector.check_for_update(existing_version)
			end

			-- If there's an existing version and it's not the latest, ask for upgrade
			if existing_version and has_update and latest_version then
				local message = string.format(
					"JUnit jar version %s is installed. A newer version %s is available. Would you like to upgrade?",
					existing_version.version,
					latest_version.version
				)
				ask_user_consent_fn(message, { "Yes, upgrade", "No, keep current version" }, function(choice)
					if choice == "Yes, upgrade" then
						-- Remove old version
						if existing_filepath and exists_fn(existing_filepath:to_string()) then
							delete_file_fn(existing_filepath:to_string())
							logger.info("Removed old JUnit jar: " .. existing_filepath:to_string())
						end

						-- Download new version
						if download_junit_jar(latest_version, default_junit_jar_filepath) then
							notify_fn(
								string.format(
									"Upgraded JUnit jar from %s to %s successfully at: \n%s",
									existing_version.version,
									latest_version.version,
									default_junit_jar_filepath:to_string()
								)
							)
						end
					else
						notify_fn("Keeping current JUnit jar version " .. existing_version.version)
					end
				end)
				return
			end

			-- If no existing version or user wants fresh install, download latest
			if not existing_version or not exists_fn(filepath_str) then
				local message = "JUnit Platform Console Standalone jar is required. Would you like to download it now?"
				ask_user_consent_fn(message, { "Yes, download", "No, cancel" }, function(choice)
					if choice == "Yes, download" then
						if download_junit_jar(config.default_junit_jar_version, default_junit_jar_filepath) then
							notify_fn(
								"Downloaded JUnit Standalone successfully at: \n"
									.. default_junit_jar_filepath:to_string()
							)
						end
					else
						notify_fn("Setup cancelled. You can run :NeotestJava setup later to download the JUnit jar.")
					end
				end)
			else
				notify_fn("JUnit jar is already set up!")
			end
		end,
	}
end

return Installer
