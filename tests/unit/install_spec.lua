local Installer = require("neotest-java.install")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

describe("Installer", function()
	local version_6_0_1 = {
		version = "6.0.1",
		sha256 = "3009120b7953bfe63add272e65b2bbeca0d41d0dfd8dea605201db15b640e0ff",
	}
	local version_1_10_1 = {
		version = "1.10.1",
		sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
	}

	local default_config = {
		junit_jar = Path("/data/junit-6.0.1.jar"),
		default_junit_jar_filepath = Path("/data/junit-6.0.1.jar"),
		default_junit_jar_version = version_6_0_1,
	}

	it("should notify when already set up with latest version", function()
		local notifications = {}
		local exists_fn = function(filepath)
			return filepath == "/data/junit-6.0.1.jar"
		end

		local checksum_fn = function(_file_path)
			return version_6_0_1.sha256
		end

		local deps = {
			exists = exists_fn,
			checksum = checksum_fn,
			notify = function(message, level)
				table.insert(notifications, { message = message, level = level })
			end,
			detect_existing_version = function()
				return nil, nil
			end,
		}

		local installer = Installer(deps)
		installer.install(default_config)

		eq(1, #notifications)
		eq("JUnit jar is already set up with the latest version!", notifications[1].message)
	end)

	it("should ask for upgrade when older version is detected", function()
		local notifications = {}
		local user_choices = {}
		local downloads = {}

		local exists_fn = function(filepath)
			-- Return true for old version, false for new version (not downloaded yet)
			return filepath == "/data/junit-1.10.1.jar"
		end

		local checksum_fn = function(file_path)
			local path_str = file_path:to_string()
			-- Return checksum based on file path
			if path_str:match("1%.10%.1") then
				return version_1_10_1.sha256
			elseif path_str:match("6%.0%.1") then
				return version_6_0_1.sha256
			end
			return version_6_0_1.sha256
		end

		local ask_user_consent_fn = function(message, choices, callback)
			table.insert(user_choices, { message = message, choices = choices })
			-- Simulate user choosing "Yes, upgrade"
			callback("Yes, upgrade")
		end

		local download_fn = function(url, output)
			table.insert(downloads, { url = url, output = output })
			return { code = 0, stderr = "" }
		end

		local delete_file_fn = function(_filepath)
			-- Mock delete
		end

		local deps = {
			exists = exists_fn,
			checksum = checksum_fn,
			notify = function(message, level)
				table.insert(notifications, { message = message, level = level })
			end,
			detect_existing_version = function()
				return version_1_10_1, Path("/data/junit-1.10.1.jar")
			end,
			ask_user_consent = ask_user_consent_fn,
			download = download_fn,
			delete_file = delete_file_fn,
		}

		local installer = Installer(deps)
		installer.install(default_config)

		-- Should have asked for upgrade
		eq(1, #user_choices)
		assert(user_choices[1].message:match("upgrade"), "Should ask about upgrade")

		-- Should have downloaded new version
		eq(1, #downloads)
		assert(downloads[1].url:match("6%.0%.1"), "Should download version 6.0.1")

		-- Should have notified about upgrade
		local upgrade_notification = false
		for _, notif in ipairs(notifications) do
			if notif.message:match("Upgraded") then
				upgrade_notification = true
				break
			end
		end
		assert(upgrade_notification, "Should notify about upgrade")
	end)

	it("should keep current version when user declines upgrade", function()
		local notifications = {}
		local user_choices = {}

		local exists_fn = function(filepath)
			return filepath == "/data/junit-1.10.1.jar"
		end

		local checksum_fn = function(_file_path)
			return version_1_10_1.sha256
		end

		local ask_user_consent_fn = function(message, choices, callback)
			table.insert(user_choices, { message = message, choices = choices })
			-- Simulate user choosing "No, keep current version"
			callback("No, keep current version")
		end

		local deps = {
			exists = exists_fn,
			checksum = checksum_fn,
			notify = function(message, level)
				table.insert(notifications, { message = message, level = level })
			end,
			detect_existing_version = function()
				return version_1_10_1, Path("/data/junit-1.10.1.jar")
			end,
			ask_user_consent = ask_user_consent_fn,
		}

		local installer = Installer(deps)
		installer.install(default_config)

		-- Should have asked for upgrade
		eq(1, #user_choices)

		-- Should have notified about keeping current version
		local keep_notification = false
		for _, notif in ipairs(notifications) do
			if notif.message:match("Keeping current") then
				keep_notification = true
				break
			end
		end
		assert(keep_notification, "Should notify about keeping current version")
	end)

	it("should ask for download when no version exists", function()
		local notifications = {}
		local user_choices = {}
		local downloads = {}

		local exists_fn = function()
			return false
		end

		local ask_user_consent_fn = function(message, choices, callback)
			table.insert(user_choices, { message = message, choices = choices })
			-- Simulate user choosing "Yes, download"
			callback("Yes, download")
		end

		local download_fn = function(url, output)
			table.insert(downloads, { url = url, output = output })
			return { code = 0, stderr = "" }
		end

		local checksum_fn = function(_file_path)
			return version_6_0_1.sha256
		end

		local deps = {
			exists = exists_fn,
			checksum = checksum_fn,
			notify = function(message, level)
				table.insert(notifications, { message = message, level = level })
			end,
			detect_existing_version = function()
				return nil, nil
			end,
			ask_user_consent = ask_user_consent_fn,
			download = download_fn,
		}

		local installer = Installer(deps)
		installer.install(default_config)

		-- Should have asked for download
		eq(1, #user_choices)
		assert(user_choices[1].message:match("download"), "Should ask about download")

		-- Should have downloaded
		eq(1, #downloads)
		assert(downloads[1].url:match("6%.0%.1"), "Should download version 6.0.1")

		-- Should have notified about download
		local download_notification = false
		for _, notif in ipairs(notifications) do
			if notif.message:match("Downloaded") then
				download_notification = true
				break
			end
		end
		assert(download_notification, "Should notify about download")
	end)

	it("should handle download error", function()
		local notifications = {}

		local exists_fn = function()
			return false
		end

		local ask_user_consent_fn = function(_message, _choices, callback)
			callback("Yes, download")
		end

		local download_fn = function(_url, _output)
			return { code = 1, stderr = "Network error" }
		end

		local deps = {
			exists = exists_fn,
			notify = function(message, level)
				table.insert(notifications, { message = message, level = level })
			end,
			detect_existing_version = function()
				return nil, nil
			end,
			ask_user_consent = ask_user_consent_fn,
			download = download_fn,
		}

		local installer = Installer(deps)
		installer.install(default_config)

		-- Should have error notification
		local error_notification = false
		for _, notif in ipairs(notifications) do
			if notif.level == "error" or notif.message:match("Error") then
				error_notification = true
				break
			end
		end
		assert(error_notification, "Should notify about error")
	end)

	it("should handle checksum verification failure", function()
		local notifications = {}
		local deleted_files = {}

		local exists_fn = function()
			return false
		end

		local ask_user_consent_fn = function(_message, _choices, callback)
			callback("Yes, download")
		end

		local download_fn = function(_url, _output)
			return { code = 0, stderr = "" }
		end

		local checksum_fn = function(_file_path)
			-- Return wrong checksum
			return "wrong_checksum"
		end

		local delete_file_fn = function(filepath)
			table.insert(deleted_files, filepath)
		end

		local deps = {
			exists = exists_fn,
			checksum = checksum_fn,
			notify = function(message, level)
				table.insert(notifications, { message = message, level = level })
			end,
			detect_existing_version = function()
				return nil, nil
			end,
			ask_user_consent = ask_user_consent_fn,
			download = download_fn,
			delete_file = delete_file_fn,
		}

		local installer = Installer(deps)
		installer.install(default_config)

		-- Should have deleted the file
		eq(1, #deleted_files)

		-- Should have error notification about checksum
		local checksum_error = false
		for _, notif in ipairs(notifications) do
			if notif.message:match("Checksum") then
				checksum_error = true
				break
			end
		end
		assert(checksum_error, "Should notify about checksum error")
	end)
end)
