local default_config = require("neotest-java.default_config")
local Path = require("neotest-java.model.path")
local JunitVersionDetector = require("neotest-java.util.junit_version_detector")
local Tree = require("neotest.types").Tree
local eq = require("tests.assertions").eq

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
			local configured_path = Path("/data/junit-6.0.3.jar")
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

	describe("public DI API", function()
		it("uses custom client_provider when provided", function()
			local custom_client_provider_called = false
			local custom_client_provider = function(_cwd)
				custom_client_provider_called = true
				return {
					initialized = true,
					request = function() end,
				}
			end

			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
				client_provider = custom_client_provider,
			})

			assert(adapter ~= nil, "Adapter should be created")
			assert(not custom_client_provider_called, "client_provider should not be called during initialization")
		end)

		it("uses custom classpath_provider when provided", function()
			local custom_classpath_called = false
			local custom_classpath_provider = {
				get_classpath = function(_base_dir, _additional_entries)
					custom_classpath_called = true
					return "/custom/classpath"
				end,
			}

			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
				classpath_provider = custom_classpath_provider,
			})

			assert(adapter ~= nil, "Adapter should be created")
			assert(not custom_classpath_called, "classpath_provider should not be called during initialization")
		end)

		it("uses custom binaries when provided", function()
			local custom_binaries = {
				java = function(_cwd)
					return Path("/custom/java")
				end,
				javap = function(_cwd)
					return Path("/custom/javap")
				end,
			}

			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
				binaries = custom_binaries,
			})

			assert(adapter ~= nil, "Adapter should be created")
		end)

		it("uses custom lsp_compiler when provided", function()
			local custom_compiler_called = false
			local custom_compiler = {
				compile = function(_args)
					custom_compiler_called = true
				end,
			}

			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
				lsp_compiler = custom_compiler,
			})

			assert(adapter ~= nil, "Adapter should be created")
			assert(not custom_compiler_called, "lsp_compiler should not be called during initialization")
		end)

		it("uses custom build_tool_getter when provided", function()
			local custom_getter_called = false
			local custom_build_tool_getter = function(_project_type)
				custom_getter_called = true
				return {
					get_build_dirname = function(_base_dir)
						return Path("custom-build")
					end,
					get_project_filename = function()
						return "custom.xml"
					end,
					get_artifact_id = function(_base_dir)
						return "custom-artifact"
					end,
				}
			end

			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
				build_tool_getter = custom_build_tool_getter,
			})

			assert(adapter ~= nil, "Adapter should be created")
			assert(not custom_getter_called, "build_tool_getter should not be called during initialization")
		end)

		it("uses custom method_id_resolver when provided", function()
			local custom_resolver_called = false
			local custom_resolver = {
				resolve_complete_method_id = function(_classname, method_id, _module_dir)
					custom_resolver_called = true
					return method_id .. "()"
				end,
			}

			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
				method_id_resolver = custom_resolver,
			})

			assert(adapter ~= nil, "Adapter should be created")
			assert(not custom_resolver_called, "method_id_resolver should not be called during initialization")
		end)

		it("uses defaults when no overrides provided (backward compatibility)", function()
			local adapter = require("neotest-java")({}, {
				root_finder = {
					find_root = function()
						return "/some/root"
					end,
				},
			})

			assert(adapter ~= nil, "Adapter should be created with defaults")
			assert(adapter.config ~= nil, "Adapter should have config")
			assert(adapter.name == "neotest-java", "Adapter should have correct name")
		end)
	end)
end)
