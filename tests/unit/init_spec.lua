local default_config = require("neotest-java.default_config")
local Path = require("neotest-java.model.path")
local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local Tree = require("neotest.types").Tree
local eq = assert.are.same

describe("NeotestJava plugin", function()
	-- Mock Factory: Creates a simple version detector for testing
	local function create_mock_detector(opts)
		opts = opts or {}
		return JunitVersionDetector({
			exists = opts.exists or function()
				return false
			end,
			checksum = opts.checksum or function()
				return "dummy"
			end,
			scan = opts.scan or function()
				return {}
			end,
			stdpath_data = opts.stdpath_data or function()
				return "data"
			end,
		})
	end

	-- Mock Factory: Creates plugin dependencies for testing
	local function create_mock_plugin_deps(opts)
		opts = opts or {}
		return {
			root_finder = {
				find_root = opts.find_root or function()
					return nil
				end,
			},
			check_junit_jar_deps = opts.check_junit_jar_deps,
		}
	end

	it("should init default configuration", function()
		-- Test 1: Init without any config
		local adapter = require("neotest-java")
		eq(default_config, adapter.config)

		-- Test 2: Init with empty config object
		adapter = require("neotest-java")({})
		eq(default_config, adapter.config)
	end)

	it("should use detected version when configured jar does not exist", function()
		-- Given: Configured jar doesn't exist, but old version (1.10.1) is detected
		local configured_path = Path("/data/junit-6.0.1.jar")
		local detected_path = Path("/data/junit-1.10.1.jar")
		local file_exists_calls = {}

		local mock_detector = create_mock_detector()
		mock_detector.detect_existing_version = function()
			return { version = "1.10.1", sha256 = "dummy" }, detected_path
		end

		local deps = create_mock_plugin_deps({
			find_root = function()
				return "/some/root"
			end,
			check_junit_jar_deps = {
				file_exists = function(filepath)
					table.insert(file_exists_calls, filepath)
					return false -- Configured jar doesn't exist
				end,
				version_detector = mock_detector,
			},
		})

		-- When: Initializing adapter and building spec
		local adapter = require("neotest-java")({ junit_jar = configured_path }, deps)

		local minimal_tree = Tree.from_list({
			id = "com.example.Test#testMethod()",
			path = "/some/root/src/test/java/com/example/Test.java",
			name = "testMethod",
			type = "test",
		}, function(x)
			return x
		end)

		pcall(function()
			adapter.build_spec({ tree = minimal_tree })
		end)

		-- Then: Should check configured path and detect existing version
		assert(#file_exists_calls >= 1, "file_exists should be called at least once")
		eq(configured_path:to_string(), file_exists_calls[1])
		eq(configured_path, adapter.config.junit_jar)
	end)

	it("does not throw when adapter is initialized outside of a java project", function()
		-- Given: Adapter initialized outside a Java project (no root found)
		local deps = create_mock_plugin_deps()

		-- When: Initializing adapter and calling root()
		local adapter = require("neotest-java")({}, deps)
		local root_result = adapter.root("some_dir")

		-- Then: Should return nil without throwing
		eq(nil, root_result)
	end)

	it("should respect disable_update_notifications config option", function()
		-- Given: Two adapters with different notification settings
		local deps = create_mock_plugin_deps()

		-- When: Creating adapters with different disable_update_notifications values
		local adapter_with_notifications = require("neotest-java")({
			disable_update_notifications = false,
		}, deps)

		local adapter_without_notifications = require("neotest-java")({
			disable_update_notifications = true,
		}, deps)

		-- Then: Config should reflect the user's choice
		eq(false, adapter_with_notifications.config.disable_update_notifications)
		eq(true, adapter_without_notifications.config.disable_update_notifications)
	end)
end)
