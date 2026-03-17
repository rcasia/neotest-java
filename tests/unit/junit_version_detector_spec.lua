local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

describe("JUnit Version Detector", function()
	local JUNIT_VERSIONS = {
		v6_0_3 = {
			version = "6.0.3",
			sha256 = "3ba0d6150af79214a1411f9ea2fbef864eef68b68c89a17f672c0b89bff9d3a2",
		},
		v6_0_1 = {
			version = "6.0.1",
			sha256 = "3009120b7953bfe63add272e65b2bbeca0d41d0dfd8dea605201db15b640e0ff",
		},
		v1_10_1 = {
			version = "1.10.1",
			sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
		},
	}

	describe("detection strategy", function()
		it("prioritizes filename-based detection", function()
			local detection_attempts = {}
			local data_dir = "data"
			local expected_path =
				Path(data_dir):append("neotest-java"):append("junit-platform-console-standalone-6.0.1.jar")

			local detector = JunitVersionDetector({
				exists = function(filepath)
					table.insert(detection_attempts, { method = "filename", path = filepath })
					return filepath == expected_path
				end,
				checksum = function()
					table.insert(detection_attempts, { method = "checksum" })
					return JUNIT_VERSIONS.v6_0_1.sha256
				end,
				scan = function()
					table.insert(detection_attempts, { method = "scan" })
					return {}
				end,
				stdpath_data = function()
					return data_dir
				end,
			})

			local version, path = detector.detect_existing_version()

			-- Should detect by filename first without scanning
			eq(JUNIT_VERSIONS.v6_0_1.version, version.version)
			eq(expected_path, path)

			-- Verify detection strategy: filename check → checksum verify, NO scan
			local used_scan = false
			for _, attempt in ipairs(detection_attempts) do
				if attempt.method == "scan" then
					used_scan = true
				end
			end
			assert(not used_scan, "Should NOT scan filesystem when filename matches")
		end)

		it("falls back to checksum-based detection when filename doesn't match", function()
			local detection_attempts = {}
			local custom_jar = Path("data"):append("neotest-java"):append("my-custom-junit.jar")

			local detector = JunitVersionDetector({
				exists = function()
					table.insert(detection_attempts, { method = "filename_check" })
					return false -- No standard filename found
				end,
				scan = function()
					table.insert(detection_attempts, { method = "filesystem_scan" })
					return { custom_jar }
				end,
				checksum = function(path)
					table.insert(detection_attempts, { method = "checksum", path = path })
					if Path(path:to_string()) == custom_jar then
						return JUNIT_VERSIONS.v1_10_1.sha256
					end
					return "unknown"
				end,
				stdpath_data = function()
					return "data"
				end,
			})

			local version, path = detector.detect_existing_version()

			-- Should detect version by checksum despite non-standard filename
			eq(JUNIT_VERSIONS.v1_10_1.version, version.version)
			eq(custom_jar, path)

			-- Verify fallback strategy was used: filename checks failed → scan → checksum
			local used_scan = false
			local used_checksum = false
			for _, attempt in ipairs(detection_attempts) do
				if attempt.method == "filesystem_scan" then
					used_scan = true
				end
				if attempt.method == "checksum" then
					used_checksum = true
				end
			end

			assert(used_scan, "Should scan filesystem when filename doesn't match")
			assert(used_checksum, "Should verify by checksum after scanning")
		end)

		it("returns nil when no JUnit jar exists", function()
			local detector = JunitVersionDetector({
				exists = function()
					return false
				end,
				scan = function()
					return {} -- Empty directory
				end,
				checksum = function()
					return "unknown"
				end,
				stdpath_data = function()
					return "data"
				end,
			})

			local version, path = detector.detect_existing_version()

			eq(nil, version)
			eq(nil, path)
		end)
	end)

	describe("update detection", function()
		it("detects when update is available", function()
			local detector = JunitVersionDetector({
				exists = function()
					return false
				end,
				checksum = function()
					return "dummy"
				end,
				scan = function()
					return {}
				end,
				stdpath_data = function()
					return "data"
				end,
			})

			local has_update, latest = detector.check_for_update(JUNIT_VERSIONS.v1_10_1)

			eq(true, has_update)
			assert(latest ~= nil, "Should return latest version info")
			assert(latest.version > JUNIT_VERSIONS.v1_10_1.version, "Latest version should be newer")
		end)

		it("detects when already on latest version", function()
			local detector = JunitVersionDetector({
				exists = function()
					return true
				end,
				checksum = function()
					return ""
				end,
				scan = function()
					return {}
				end,
				stdpath_data = function()
					return "data"
				end,
			})

			local has_update, latest = detector.check_for_update(JUNIT_VERSIONS.v6_0_3)

			eq(false, has_update)
			eq(nil, latest)
		end)
	end)
end)
