local Installer = require("neotest-java.install")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

describe("Installer", function()
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

	local function create_config(version)
		version = version or JUNIT_VERSIONS.v6_0_1
		local jar_path = Path(string.format("/data/junit-%s.jar", version.version))
		return {
			junit_jar = jar_path,
			default_junit_jar_filepath = jar_path,
			default_junit_jar_version = version,
		}
	end

	describe("installation workflow", function()
		it("skips installation when latest version already exists", function()
			local actions = {}
			local jar_path = Path("/data/junit-6.0.1.jar")

			local installer = Installer({
				exists = function(filepath)
					return Path(filepath) == jar_path
				end,
				checksum = function()
					return JUNIT_VERSIONS.v6_0_1.sha256
				end,
				notify = function(message)
					table.insert(actions, { type = "notify", message = message })
				end,
				detect_existing_version = function()
					return nil, nil
				end,
				ask_user_consent = function()
					table.insert(actions, { type = "ask_consent" })
				end,
				download = function()
					table.insert(actions, { type = "download" })
					return { code = 0, stderr = "" }
				end,
				delete_file = function()
					table.insert(actions, { type = "delete" })
				end,
			})

			installer.install(create_config())

			-- Verify workflow: should only notify, no download or user prompt
			eq(1, #actions)
			eq("notify", actions[1].type)
			assert(actions[1].message:match("already set up"), "Should notify that setup is complete")
		end)

		it("prompts for upgrade when old version exists", function()
			local workflow = {}

			local installer = Installer({
				exists = function()
					return false -- Configured jar doesn't exist
				end,
				checksum = function()
					return JUNIT_VERSIONS.v6_0_1.sha256
				end,
				notify = function(message)
					table.insert(workflow, { action = "notify", detail = message })
				end,
				detect_existing_version = function()
					table.insert(workflow, { action = "detect_version" })
					return JUNIT_VERSIONS.v1_10_1, Path("/data/junit-1.10.1.jar")
				end,
				ask_user_consent = function(message, _, callback)
					table.insert(workflow, { action = "ask_consent", detail = message })
					callback("Yes, upgrade")
				end,
				download = function(url)
					table.insert(workflow, { action = "download", url = url })
					return { code = 0, stderr = "" }
				end,
				delete_file = function(filepath)
					table.insert(workflow, { action = "delete", filepath = filepath })
				end,
			})

			installer.install(create_config())

			-- Verify workflow sequence: detect → ask → delete old → download new → notify
			assert(#workflow >= 4, "Should execute multi-step workflow")

			local has_detect = false
			local has_ask = false
			local has_download = false
			for _, step in ipairs(workflow) do
				if step.action == "detect_version" then
					has_detect = true
				end
				if step.action == "ask_consent" and step.detail:match("upgrade") then
					has_ask = true
				end
				if step.action == "download" and step.url:match("6%.0%.1") then
					has_download = true
				end
			end

			assert(has_detect, "Should detect existing version")
			assert(has_ask, "Should ask user for upgrade consent")
			assert(has_download, "Should download new version")
		end)

		it("respects user decision to keep old version", function()
			local workflow = {}

			local installer = Installer({
				exists = function()
					return false
				end,
				checksum = function()
					return JUNIT_VERSIONS.v1_10_1.sha256
				end,
				notify = function(message)
					table.insert(workflow, { action = "notify", detail = message })
				end,
				detect_existing_version = function()
					return JUNIT_VERSIONS.v1_10_1, Path("/data/junit-1.10.1.jar")
				end,
				ask_user_consent = function(_, _, callback)
					table.insert(workflow, { action = "ask_consent" })
					callback("No, keep current version")
				end,
				download = function()
					table.insert(workflow, { action = "download" })
					return { code = 0, stderr = "" }
				end,
				delete_file = function()
					table.insert(workflow, { action = "delete" })
				end,
			})

			installer.install(create_config())

			-- Verify workflow: should ask, then notify about keeping, but NOT download
			local has_download = false
			local has_keep_notification = false
			for _, step in ipairs(workflow) do
				if step.action == "download" then
					has_download = true
				end
				if step.action == "notify" and step.detail:match("Keeping") then
					has_keep_notification = true
				end
			end

			assert(not has_download, "Should NOT download when user declines")
			assert(has_keep_notification, "Should notify about keeping current version")
		end)

		it("prompts for fresh install when no version exists", function()
			local workflow = {}

			local installer = Installer({
				exists = function()
					return false
				end,
				checksum = function()
					return JUNIT_VERSIONS.v6_0_1.sha256
				end,
				notify = function()
					table.insert(workflow, { action = "notify" })
				end,
				detect_existing_version = function()
					return nil, nil
				end,
				ask_user_consent = function(message, _, callback)
					table.insert(workflow, { action = "ask_consent", detail = message })
					callback("Yes, download")
				end,
				download = function()
					table.insert(workflow, { action = "download" })
					return { code = 0, stderr = "" }
				end,
				delete_file = function()
					table.insert(workflow, { action = "delete" })
				end,
			})

			installer.install(create_config())

			-- Verify workflow: should ask for download permission
			local has_download_prompt = false
			local has_download = false
			for _, step in ipairs(workflow) do
				if step.action == "ask_consent" and step.detail:match("download") then
					has_download_prompt = true
				end
				if step.action == "download" then
					has_download = true
				end
			end

			assert(has_download_prompt, "Should prompt for download permission")
			assert(has_download, "Should download after user consent")
		end)
	end)

	describe("error handling", function()
		it("handles download failures gracefully", function()
			local error_logged = false

			local installer = Installer({
				exists = function()
					return false
				end,
				checksum = function()
					return JUNIT_VERSIONS.v6_0_1.sha256
				end,
				notify = function(message, level)
					if level == "error" or message:match("Error") then
						error_logged = true
					end
				end,
				detect_existing_version = function()
					return nil, nil
				end,
				ask_user_consent = function(_, _, callback)
					callback("Yes, download")
				end,
				download = function()
					return { code = 1, stderr = "Network timeout" }
				end,
				delete_file = function() end,
			})

			installer.install(create_config())

			assert(error_logged, "Should log error when download fails")
		end)

		it("verifies checksum and removes corrupted downloads", function()
			local corrupted_file_deleted = false

			local installer = Installer({
				exists = function()
					return false
				end,
				checksum = function()
					return "corrupted_checksum"
				end,
				notify = function() end,
				detect_existing_version = function()
					return nil, nil
				end,
				ask_user_consent = function(_, _, callback)
					callback("Yes, download")
				end,
				download = function()
					return { code = 0, stderr = "" }
				end,
				delete_file = function()
					corrupted_file_deleted = true
				end,
			})

			installer.install(create_config())

			assert(corrupted_file_deleted, "Should delete file when checksum verification fails")
		end)
	end)
end)
