local default_config = require("neotest-java.default_config")
local Path = require("neotest-java.model.path")
local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local Tree = require("neotest.types").Tree
local eq = assert.are.same

describe("NeotestJava plugin", function()
	describe("initialization", function()
		it("uses default config when no user config provided", function()
			local adapter = require("neotest-java")
			eq(default_config, adapter.config)
		end)

		it("merges user config with defaults", function()
			local adapter = require("neotest-java")({
				disable_update_notifications = true,
			})

			eq(true, adapter.config.disable_update_notifications)
			-- Other defaults should still be present
			assert(adapter.config.junit_jar ~= nil, "Should have default junit_jar")
		end)
	end)

	describe("JUnit jar fallback behavior", function()
		it("falls back to detected version when configured jar missing", function()
			local configured_path = Path("/data/junit-6.0.1.jar")
			local detected_path = Path("/data/junit-1.10.1.jar")
			local fallback_occurred = false

			local mock_detector = JunitVersionDetector({
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

			mock_detector.detect_existing_version = function()
				fallback_occurred = true
				return { version = "1.10.1", sha256 = "dummy" }, detected_path
			end

			local adapter = require("neotest-java")({ junit_jar = configured_path }, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
				check_junit_jar_deps = {
					file_exists = function()
						return false -- Configured jar doesn't exist
					end,
					version_detector = mock_detector,
				},
			})

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

			assert(fallback_occurred, "Should attempt to detect existing version when configured jar missing")
		end)
	end)

	describe("graceful degradation", function()
		it("handles being initialized outside Java project", function()
			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return nil
					end,
				},
			})

			local root_result = adapter.root("some_dir")

			eq(nil, root_result)
		end)
	end)

	describe("configuration options", function()
		it("respects disable_update_notifications setting", function()
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

			eq(false, adapter_with_notifications.config.disable_update_notifications)
			eq(true, adapter_without_notifications.config.disable_update_notifications)
		end)
	end)
end)
