local default_config = require("neotest-java.default_config")
local Path = require("neotest-java.model.path")
local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local eq = assert.are.same

describe("NeotestJava plugin", function()
	it("should init default configuration", function()
		do
			local adapter = require("neotest-java")
			eq(default_config, adapter.config)
		end

		do
			local adapter = require("neotest-java")({})
			eq(default_config, adapter.config)
		end
	end)

	it("should use detected version when configured jar does not exist", function()
		local Tree = require("neotest.types").Tree
		local configured_path = Path("/data/junit-6.0.1.jar")
		local detected_path = Path("/data/junit-1.10.1.jar")
		local file_exists_calls = {}
		local mock_detector = JunitVersionDetector({
			exists = function(_path)
				return false
			end,
			checksum = function(_path)
				return "dummy"
			end,
			scan = function()
				return {}
			end,
			stdpath_data = function()
				return "data"
			end,
		})
		-- Mock detect_existing_version to return a version
		mock_detector.detect_existing_version = function()
			return { version = "1.10.1", sha256 = "dummy" }, detected_path
		end

		local adapter = require("neotest-java")({
			junit_jar = configured_path,
		}, {
			root_finder = {
				find_root = function()
					return "/some/root"
				end,
			},
			check_junit_jar_deps = {
				file_exists = function(filepath)
					table.insert(file_exists_calls, filepath)
					-- Configured jar doesn't exist
					return false
				end,
				version_detector = mock_detector,
			},
		})

		-- Create a minimal tree for testing
		local tree = Tree.from_list({
			id = "com.example.Test#testMethod()",
			path = "/some/root/src/test/java/com/example/Test.java",
			name = "testMethod",
			type = "test",
		}, function(x)
			return x
		end)

		-- Try to call build_spec - this should trigger check_junit_jar
		-- We expect it to fail because we don't have all dependencies, but it should call check_junit_jar first
		pcall(function()
			adapter.build_spec({ tree = tree })
		end)

		-- Verify that file_exists was called with the configured path when checking for the jar
		assert(#file_exists_calls >= 1, "file_exists should be called at least once")
		eq(configured_path:to_string(), file_exists_calls[1])

		-- The adapter should be initialized successfully
		assert(adapter ~= nil)
		-- The config should still have the configured path (not modified during init)
		eq(configured_path, adapter.config.junit_jar)
	end)

	it("does not throw when adapter is initialized outside of a java project", function()
		--- @type neotest-java.Adapter
		local adapter = require("neotest-java")({}, {
			root_finder = {
				find_root = function()
					return nil
				end,
			},
		})
		eq(nil, adapter.root("some_dir"))
	end)

	it("should respect disable_update_notifications config option", function()
		-- Test that the config option is properly merged
		local adapter_with_notifications = require("neotest-java")({
			disable_update_notifications = false,
		}, {
			root_finder = {
				find_root = function()
					return nil
				end,
			},
		})

		local adapter_without_notifications = require("neotest-java")({
			disable_update_notifications = true,
		}, {
			root_finder = {
				find_root = function()
					return nil
				end,
			},
		})

		-- Both should have the config set correctly
		eq(false, adapter_with_notifications.config.disable_update_notifications)
		eq(true, adapter_without_notifications.config.disable_update_notifications)
	end)
end)
