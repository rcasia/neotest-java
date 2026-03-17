local Installer = require("neotest-java.install")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

describe("Installer", function()
	-- Test Fixtures: Known JUnit versions for testing
	local JUNIT_VERSIONS = {
		v6_0_1 = {
			version = "6.0.1",
			sha256 = "3009120b7953bfe63add272e65b2bbeca0d41d0dfd8dea605201db15b640e0ff",
		},
		v1_10_1 = {
			version = "1.10.1",
			sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
		},
	}

	-- Test Data Builder: Creates a default config object
	local function create_config(version)
		version = version or JUNIT_VERSIONS.v6_0_1
		local jar_path = Path(string.format("/data/junit-%s.jar", version.version))
		return {
			junit_jar = jar_path,
			default_junit_jar_filepath = jar_path,
			default_junit_jar_version = version,
		}
	end

	-- Mock Factory: Creates installer dependencies with sensible defaults
	-- All functions can be overridden by passing options
	local function create_mock_deps(opts)
		opts = opts or {}
		local notifications = opts.notifications or {}
		local user_choices = opts.user_choices or {}
		local downloads = opts.downloads or {}
		local deleted_files = opts.deleted_files or {}

		return {
			exists = opts.exists or function()
				return false
			end,
			checksum = opts.checksum or function()
				return JUNIT_VERSIONS.v6_0_1.sha256
			end,
			notify = function(message, level)
				table.insert(notifications, { message = message, level = level })
			end,
			detect_existing_version = opts.detect_existing_version or function()
				return nil, nil
			end,
			ask_user_consent = opts.ask_user_consent or function(_message, _choices, callback)
				callback("No, cancel")
			end,
			download = opts.download or function(url, output)
				table.insert(downloads, { url = url, output = output })
				return { code = 0, stderr = "" }
			end,
			delete_file = function(filepath)
				table.insert(deleted_files, filepath)
			end,
		}
	end

	-- Helper: Find notification by pattern
	local function find_notification(notifications, pattern)
		for _, notif in ipairs(notifications) do
			if notif.message:match(pattern) then
				return notif
			end
		end
		return nil
	end

	it("should notify when already set up with latest version", function()
		-- Given: Latest version (6.0.1) already exists with correct checksum
		local notifications = {}
		local jar_path = Path("/data/junit-6.0.1.jar")

		local deps = create_mock_deps({
			notifications = notifications,
			exists = function(filepath)
				return Path(filepath) == jar_path
			end,
			checksum = function()
				return JUNIT_VERSIONS.v6_0_1.sha256
			end,
		})

		-- When: Running installer
		local installer = Installer(deps)
		installer.install(create_config())

		-- Then: Should notify that setup is complete
		eq(1, #notifications)
		eq("JUnit jar is already set up with the latest version!", notifications[1].message)
	end)

	it("should ask for upgrade when older version is detected", function()
		-- Given: Old version (1.10.1) exists, newer version (6.0.1) available
		local notifications = {}
		local user_choices = {}
		local downloads = {}
		local old_jar_path = Path("/data/junit-1.10.1.jar")

		local deps = create_mock_deps({
			notifications = notifications,
			user_choices = user_choices,
			downloads = downloads,
			exists = function(filepath)
				-- Old version exists, new version doesn't
				return Path(filepath) == old_jar_path
			end,
			checksum = function(file_path)
				-- Return appropriate checksum based on file path
				if file_path:to_string():match("1%.10%.1") then
					return JUNIT_VERSIONS.v1_10_1.sha256
				end
				return JUNIT_VERSIONS.v6_0_1.sha256
			end,
			detect_existing_version = function()
				return JUNIT_VERSIONS.v1_10_1, old_jar_path
			end,
			ask_user_consent = function(message, choices, callback)
				table.insert(user_choices, { message = message, choices = choices })
				callback("Yes, upgrade")
			end,
		})

		-- When: Running installer
		local installer = Installer(deps)
		installer.install(create_config())

		-- Then: Should ask for upgrade, download new version, and notify
		eq(1, #user_choices)
		assert(user_choices[1].message:match("upgrade"), "Should ask about upgrade")

		eq(1, #downloads)
		assert(downloads[1].url:match("6%.0%.1"), "Should download version 6.0.1")

		assert(find_notification(notifications, "Upgraded"), "Should notify about upgrade")
	end)

	it("should keep current version when user declines upgrade", function()
		-- Given: Old version exists, user declines upgrade
		local notifications = {}
		local user_choices = {}
		local old_jar_path = Path("/data/junit-1.10.1.jar")

		local deps = create_mock_deps({
			notifications = notifications,
			user_choices = user_choices,
			exists = function(filepath)
				return Path(filepath) == old_jar_path
			end,
			checksum = function()
				return JUNIT_VERSIONS.v1_10_1.sha256
			end,
			detect_existing_version = function()
				return JUNIT_VERSIONS.v1_10_1, old_jar_path
			end,
			ask_user_consent = function(message, choices, callback)
				table.insert(user_choices, { message = message, choices = choices })
				callback("No, keep current version")
			end,
		})

		-- When: Running installer
		local installer = Installer(deps)
		installer.install(create_config())

		-- Then: Should ask for upgrade and notify about keeping current version
		eq(1, #user_choices)
		assert(find_notification(notifications, "Keeping current"), "Should notify about keeping current version")
	end)

	it("should ask for download when no version exists", function()
		-- Given: No existing JUnit jar
		local notifications = {}
		local user_choices = {}
		local downloads = {}

		local deps = create_mock_deps({
			notifications = notifications,
			user_choices = user_choices,
			downloads = downloads,
			ask_user_consent = function(message, choices, callback)
				table.insert(user_choices, { message = message, choices = choices })
				callback("Yes, download")
			end,
		})

		-- When: Running installer
		local installer = Installer(deps)
		installer.install(create_config())

		-- Then: Should ask for download, download it, and notify
		eq(1, #user_choices)
		assert(user_choices[1].message:match("download"), "Should ask about download")

		eq(1, #downloads)
		assert(downloads[1].url:match("6%.0%.1"), "Should download version 6.0.1")

		assert(find_notification(notifications, "Downloaded"), "Should notify about download")
	end)

	it("should handle download error", function()
		-- Given: Download will fail with network error
		local notifications = {}

		local deps = create_mock_deps({
			notifications = notifications,
			ask_user_consent = function(_message, _choices, callback)
				callback("Yes, download")
			end,
			download = function()
				return { code = 1, stderr = "Network error" }
			end,
		})

		-- When: Running installer
		local installer = Installer(deps)
		installer.install(create_config())

		-- Then: Should notify about error
		assert(find_notification(notifications, "Error"), "Should notify about error")
	end)

	it("should handle checksum verification failure", function()
		-- Given: Downloaded file will have wrong checksum
		local notifications = {}
		local deleted_files = {}

		local deps = create_mock_deps({
			notifications = notifications,
			deleted_files = deleted_files,
			ask_user_consent = function(_message, _choices, callback)
				callback("Yes, download")
			end,
			checksum = function()
				return "wrong_checksum"
			end,
		})

		-- When: Running installer
		local installer = Installer(deps)
		installer.install(create_config())

		-- Then: Should delete file and notify about checksum error
		eq(1, #deleted_files)
		assert(find_notification(notifications, "Checksum"), "Should notify about checksum error")
	end)
end)
