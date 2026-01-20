local version_detector = require("neotest-java.util.junit_version_detector")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

describe("JUnit Version Detector", function()
	it("should detect existing version by filename", function()
		local version_6_0_1 = {
			version = "6.0.1",
			sha256 = "3009120b7953bfe63add272e65b2bbeca0d41d0dfd8dea605201db15b640e0ff",
		}
		local version_1_10_1 = {
			version = "1.10.1",
			sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
		}

		-- Use Path to construct expected path (works on both Windows and Unix)
		local data_dir_str = "data"
		-- Build the path exactly the same way the detector does
		local data_dir = Path(data_dir_str):append("neotest-java")
		local expected_jar_path = data_dir:append("junit-platform-console-standalone-6.0.1.jar")

		local exists_fn = function(filepath)
			if filepath ~= expected_jar_path then
				return false
			end
			return true
		end

		local checksum_fn = function(file_path)
			local path_str = file_path:to_string()
			-- Mock checksum based on path
			if path_str:match("6%.0%.1") then
				return version_6_0_1.sha256
			elseif path_str:match("1%.10%.1") then
				return version_1_10_1.sha256
			end
			return "unknown"
		end

		local deps = {
			exists = exists_fn,
			checksum = checksum_fn,
			stdpath_data = function()
				return data_dir_str
			end,
		}

		local detected_version, filepath = version_detector.detect_existing_version(deps)

		assert(detected_version ~= nil, "detected_version should not be nil")
		eq(version_6_0_1.version, detected_version.version)
		eq(version_6_0_1.sha256, detected_version.sha256)
		-- Compare using Path to handle different path formats (Windows vs Unix)
		eq(expected_jar_path, filepath)
	end)

	it("should return nil when no version is found", function()
		local exists_fn = function(_filepath)
			return false
		end

		local scan_fn = function()
			return {}
		end

		local deps = {
			exists = exists_fn,
			scan = scan_fn,
			stdpath_data = function()
				return "data"
			end,
		}

		local detected_version, filepath = version_detector.detect_existing_version(deps)

		eq(nil, detected_version)
		eq(nil, filepath)
	end)

	it("should detect version by checksum when filename doesn't match", function()
		local version_1_10_1 = {
			version = "1.10.1",
			sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
		}

		local data_dir_str = "data"
		local data_dir = Path(data_dir_str):append("neotest-java")
		local jar_file = data_dir:append("custom-junit.jar")
		local jar_file_str = jar_file:to_string()

		local exists_fn = function(_filepath)
			return false -- No file with expected filename
		end

		local scan_fn = function()
			return { jar_file }
		end

		local checksum_fn = function(file_path)
			-- Compare using Path to handle different path formats (Windows vs Unix)
			local file_path_str = Path(file_path:to_string()):to_string()
			if file_path_str == jar_file_str then
				return version_1_10_1.sha256
			end
			return "unknown"
		end

		local deps = {
			exists = exists_fn,
			scan = scan_fn,
			checksum = checksum_fn,
			stdpath_data = function()
				return data_dir_str
			end,
		}

		local detected_version, filepath = version_detector.detect_existing_version(deps)

		assert(detected_version ~= nil, "detected_version should not be nil")
		eq(version_1_10_1.version, detected_version.version)
		eq(version_1_10_1.sha256, detected_version.sha256)
		-- Compare using Path to handle different path formats (Windows vs Unix)
		eq(jar_file, filepath)
	end)

	it("should check for update when current version is older", function()
		local current_version = {
			version = "1.10.1",
			sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
		}

		local has_update, latest_version = version_detector.check_for_update(current_version)

		eq(true, has_update)
		eq("6.0.1", latest_version.version)
	end)

	it("should not find update when current version is latest", function()
		local current_version = {
			version = "6.0.1",
			sha256 = "3009120b7953bfe63add272e65b2bbeca0d41d0dfd8dea605201db15b640e0ff",
		}

		local has_update, latest_version = version_detector.check_for_update(current_version)

		eq(false, has_update)
		eq(nil, latest_version)
	end)
end)
