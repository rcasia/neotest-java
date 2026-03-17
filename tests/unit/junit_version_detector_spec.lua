local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

describe("JUnit Version Detector", function()
	-- Test Fixtures: Known JUnit versions
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

	-- Helper: Build standard JUnit jar path in neotest-java data directory
	local function build_junit_jar_path(data_dir, version)
		return Path(data_dir)
			:append("neotest-java")
			:append(string.format("junit-platform-console-standalone-%s.jar", version))
	end

	-- Mock Factory: Creates detector dependencies with sensible defaults
	local function create_mock_deps(opts)
		opts = opts or {}
		return {
			exists = opts.exists or function()
				return false
			end,
			checksum = opts.checksum or function()
				return "unknown"
			end,
			scan = opts.scan or function()
				return {}
			end,
			stdpath_data = opts.stdpath_data or function()
				return "data"
			end,
		}
	end

	it("should detect existing version by filename", function()
		-- Given: JUnit 6.0.1 jar exists with standard filename
		local data_dir = "data"
		local expected_jar_path = build_junit_jar_path(data_dir, "6.0.1")

		local deps = create_mock_deps({
			exists = function(filepath)
				return filepath == expected_jar_path
			end,
			checksum = function(file_path)
				if file_path:to_string():match("6%.0%.1") then
					return JUNIT_VERSIONS.v6_0_1.sha256
				end
				return "unknown"
			end,
			stdpath_data = function()
				return data_dir
			end,
		})

		-- When: Detecting existing version
		local detector = JunitVersionDetector(deps)
		local detected_version, filepath = detector.detect_existing_version()

		-- Then: Should detect version 6.0.1 by filename
		assert(detected_version ~= nil, "detected_version should not be nil")
		eq(JUNIT_VERSIONS.v6_0_1.version, detected_version.version)
		eq(JUNIT_VERSIONS.v6_0_1.sha256, detected_version.sha256)
		eq(expected_jar_path, filepath)
	end)

	it("should return nil when no version is found", function()
		-- Given: No JUnit jar exists in data directory
		local deps = create_mock_deps()

		-- When: Detecting existing version
		local detector = JunitVersionDetector(deps)
		local detected_version, filepath = detector.detect_existing_version()

		-- Then: Should return nil for both version and filepath
		eq(nil, detected_version)
		eq(nil, filepath)
	end)

	it("should detect version by checksum when filename doesn't match", function()
		-- Given: JUnit jar with custom filename but valid checksum
		local data_dir = "data"
		local custom_jar_path = Path(data_dir):append("neotest-java"):append("custom-junit.jar")

		local deps = create_mock_deps({
			scan = function()
				return { custom_jar_path }
			end,
			checksum = function(file_path)
				if Path(file_path:to_string()) == custom_jar_path then
					return JUNIT_VERSIONS.v1_10_1.sha256
				end
				return "unknown"
			end,
			stdpath_data = function()
				return data_dir
			end,
		})

		-- When: Detecting existing version (filename doesn't match, but checksum does)
		local detector = JunitVersionDetector(deps)
		local detected_version, filepath = detector.detect_existing_version()

		-- Then: Should detect version 1.10.1 by checksum
		assert(detected_version ~= nil, "detected_version should not be nil")
		eq(JUNIT_VERSIONS.v1_10_1.version, detected_version.version)
		eq(JUNIT_VERSIONS.v1_10_1.sha256, detected_version.sha256)
		eq(custom_jar_path, filepath)
	end)

	it("should check for update when current version is older", function()
		-- Given: Current version is 1.10.1, latest is 6.0.1
		local detector = JunitVersionDetector(create_mock_deps())

		-- When: Checking for updates with old version
		local has_update, latest_version = detector.check_for_update(JUNIT_VERSIONS.v1_10_1)

		-- Then: Should indicate update is available to 6.0.1
		eq(true, has_update)
		eq("6.0.1", latest_version.version)
	end)

	it("should not find update when current version is latest", function()
		-- Given: Current version is already 6.0.1 (latest)
		local detector = JunitVersionDetector(create_mock_deps())

		-- When: Checking for updates with latest version
		local has_update, latest_version = detector.check_for_update(JUNIT_VERSIONS.v6_0_1)

		-- Then: Should indicate no update is available
		eq(false, has_update)
		eq(nil, latest_version)
	end)
end)
