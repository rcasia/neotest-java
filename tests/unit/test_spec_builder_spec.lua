local SpecBuilder = require("neotest-java.core.spec_builder")
local Path = require("neotest-java.model.path")
local FakeBuildTool = require("tests.fake_build_tool")
local Tree = require("neotest.types").Tree
local TREES = require("tests.trees")

local assertions = require("tests.assertions")
local eq = assertions.eq

describe("SpecBuilder", function()
	local config = {
		junit_jar = Path("my-junit-jar.jar"),
	}
	it("builds a spec for two test methods", function()
		local path = Path("/user/home/root/src/test/java/com/example/Test.java")
		local parent_path = path:parent()
		local project_paths = {
			parent_path,
			parent_path:append("ExampleTest.java"),
			parent_path:append("pom.xml"),
		}

		-- when
		local spec_builder_instance = SpecBuilder({
			mkdir = function() end,

			scan = function(_base_dir, opts)
				-- if _base_dir ~= parent_path then
				-- 	error("unexpected base_dir in scan: " .. _base_dir:to_string())
				-- end

				opts = opts or {}
				if opts.search_patterns and opts.search_patterns[1] == Path("test/resources$"):to_string() then
					return { Path("additional1"), Path("additional2") }
				end

				return project_paths
			end,
			compile = function(base_dir)
				local expected_base_dir = parent_path
				assert(
					base_dir == expected_base_dir,
					"should compile with the project root as base_dir: "
						.. vim.inspect({ actual = base_dir:to_string(), expected = expected_base_dir:to_string() })
				)
			end,
			classpath_provider = {
				get_classpath = function(base_dir, additional_classpaths)
					eq(parent_path, base_dir)
					eq({ Path("additional1"), Path("additional2") }, additional_classpaths)

					return "classpath-file-argument"
				end,
			},
			report_folder_name_gen = function(module_dir, build_dir)
				eq(parent_path, module_dir)
				eq(Path("target"), build_dir)

				return Path("report_folder")
			end,
			build_tool_getter = function()
				--- @type neotest-java.BuildTool
				return FakeBuildTool
			end,
			detect_project_type = function()
				return "maven"
			end,
			binaries = {
				java = function()
					return Path("java")
				end,
			},
		})
		local actual =
			spec_builder_instance.build_spec({ tree = TREES.TWO_TESTS_IN_FILE(path), strategy = "integration" }, config)

		-- then
		eq({
			command = vim.iter({
				"java",
				"-Duser.dir=" .. parent_path:to_string(),
				"-Dspring.config.additional-location=" .. Path("src/main/resources/application.properties"):to_string(),
				"-jar",
				"my-junit-jar.jar",
				"execute",
				"--classpath=classpath-file-argument",
				"--reports-dir=report_folder",
				"--fail-if-no-tests",
				"--disable-banner",
				"--details=testfeed",
				"--config=junit.platform.output.capture.stdout=true",
				"--config=junit.platform.output.capture.stderr=true",
				"--exclude-engine=archunit",
				"--select-class='com.example.ExampleTest'",
			}):join(" "),
			context = {
				reports_dir = Path("report_folder"),
			},
			cwd = parent_path:to_string(),
			symbol = parent_path:to_string(),
		}, actual)
	end)

	it("builds spec for one method", function()
		local tree = Tree.from_list({
			id = "com.example.ExampleTest#shouldNotFail()",
			path = "/user/home/root/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		}, function(x)
			return x
		end)
		-- Add ref method to the tree node
		local position = tree:data()
		local node = tree:get_key(position.id)
		if node then
			local node_data = node:data()
			node_data.ref = function()
				return position.id
			end
		else
			-- If node is not found, add ref directly to position via metatable
			local mt = getmetatable(position) or {}
			local original_index = mt.__index
			mt.__index = function(t, k)
				if k == "ref" then
					return function()
						return position.id
					end
				end
				if original_index then
					return original_index(t, k)
				end
			end
			setmetatable(position, mt)
		end
		local test_config = {
			junit_jar = Path("my-junit-jar.jar"),
		}
		local project_paths = {
			Path("."),
			Path("./src/test/java/com/example/ExampleTest.java"),
			Path("./pom.xml"),
		}

		-- when
		local spec_builder_instance = SpecBuilder({
			mkdir = function() end,

			scan = function(_base_dir, opts)
				opts = opts or {}
				if opts.search_patterns and opts.search_patterns[1] == Path("test/resources$"):to_string() then
					return { Path("additional1"), Path("additional2") }
				end

				return project_paths
			end,
			compile = function(base_dir)
				local expected_base_dir = Path(".")
				assert(
					base_dir == Path("."),
					"should compile with the project root as base_dir: "
						.. vim.inspect({ actual = base_dir:to_string(), expected = expected_base_dir:to_string() })
				)
			end,
			classpath_provider = {
				get_classpath = function(base_dir, additional_classpaths)
					eq(Path("."), base_dir)
					eq({ Path("additional1"), Path("additional2") }, additional_classpaths)

					return "classpath-file-argument"
				end,
			},
			report_folder_name_gen = function(module_dir, build_dir)
				eq(Path("."), module_dir)
				eq(Path("target"), build_dir)

				return Path("report_folder")
			end,
			build_tool_getter = function()
				--- @type neotest-java.BuildTool
				return FakeBuildTool
			end,
			detect_project_type = function()
				return "maven"
			end,
			binaries = {
				java = function()
					return Path("java")
				end,
			},
		})
		local actual = spec_builder_instance.build_spec({ tree = tree, strategy = "integration" }, test_config)

		-- then
		eq({
			command = vim.iter({
				"java",
				"-Duser.dir=" .. Path("."):to_string(),
				"-Dspring.config.additional-location=" .. Path("src/main/resources/application.properties"):to_string(),
				"-jar",
				"my-junit-jar.jar",
				"execute",
				"--classpath=classpath-file-argument",
				"--reports-dir=report_folder",
				"--fail-if-no-tests",
				"--disable-banner",
				"--details=testfeed",
				"--config=junit.platform.output.capture.stdout=true",
				"--config=junit.platform.output.capture.stderr=true",
				"--exclude-engine=archunit",
				"--select-method='com.example.ExampleTest#shouldNotFail()'",
			}):join(" "),
			context = {
				reports_dir = Path("report_folder"),
			},
			cwd = Path("."):to_string(),
			symbol = "shouldNotFail",
		}, actual)
	end)

	it("builds spec for one method with extra args", function()
		local tree = Tree.from_list({
			id = "com.example.ExampleTest#shouldNotFail()",
			path = "/user/home/root/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		}, function(x)
			return x
		end)
		-- Add ref method to the tree node
		local position = tree:data()
		local node = tree:get_key(position.id)
		if node then
			local node_data = node:data()
			node_data.ref = function()
				return position.id
			end
		else
			-- If node is not found, add ref directly to position via metatable
			local mt = getmetatable(position) or {}
			local original_index = mt.__index
			mt.__index = function(t, k)
				if k == "ref" then
					return function()
						return position.id
					end
				end
				if original_index then
					return original_index(t, k)
				end
			end
			setmetatable(position, mt)
		end

		local args = { strategy = "integration", tree = tree }

		local test_config = {
			junit_jar = Path("my-junit-jar.jar"),
			jvm_args = { "-myExtraJvmArg" },
		}
		local project_paths = {
			Path("/user/home/root"),
			Path("/user/home/root/src/test/java/com/example/ExampleTest.java"),
			Path("/user/home/root/pom.xml"),
		}

		-- when
		local spec_builder_instance = SpecBuilder({
			mkdir = function() end,

			scan = function()
				return project_paths
			end,
			compile = function() end,
			classpath_provider = {
				get_classpath = function()
					return "classpath-file-argument"
				end,
			},
			report_folder_name_gen = function()
				return Path("report_folder")
			end,
			build_tool_getter = function()
				--- @type neotest-java.BuildTool
				return FakeBuildTool
			end,
			detect_project_type = function()
				return "maven"
			end,
			binaries = {
				java = function()
					return Path("java")
				end,
			},
		})
		local actual = spec_builder_instance.build_spec(args, test_config)

		-- then
		eq({
			command = vim.iter({
				"java",
				"-Duser.dir=" .. Path("/user/home/root"):to_string(),
				"-Dspring.config.additional-location=" .. Path("src/main/resources/application.properties"):to_string(),
				"-myExtraJvmArg",
				"-jar",
				"my-junit-jar.jar",
				"execute",
				"--classpath=classpath-file-argument",
				"--reports-dir=report_folder",
				"--fail-if-no-tests",
				"--disable-banner",
				"--details=testfeed",
				"--config=junit.platform.output.capture.stdout=true",
				"--config=junit.platform.output.capture.stderr=true",
				"--exclude-engine=archunit",
				"--select-method='com.example.ExampleTest#shouldNotFail()'",
			}):join(" "),
			context = {
				reports_dir = Path("report_folder"),
			},
			cwd = Path("/user/home/root"):to_string(),
			symbol = "shouldNotFail",
		}, actual)
	end)

	it("builds spec for one method in a multi-module project", function()
		local tree = Tree.from_list({
			id = "com.example.ExampleInSecondModuleTest#shouldNotFail()",
			path = "/user/home/root/module-2/src/test/java/com/example/ExampleInSecondModuleTest.java",
			name = "shouldNotFail",
			type = "test",
		}, function(x)
			return x
		end)
		-- Add ref method to the tree node
		local position = tree:data()
		local node = tree:get_key(position.id)
		if node then
			local node_data = node:data()
			node_data.ref = function()
				return position.id
			end
		else
			-- If node is not found, add ref directly to position via metatable
			local mt = getmetatable(position) or {}
			local original_index = mt.__index
			mt.__index = function(t, k)
				if k == "ref" then
					return function()
						return position.id
					end
				end
				if original_index then
					return original_index(t, k)
				end
			end
			setmetatable(position, mt)
		end

		local args = { strategy = "integration", tree = tree }

		local test_config = {
			junit_jar = Path("my-junit-jar.jar"),
		}
		local project_paths = {
			Path("/user/home/root"),
			Path("/user/home/root/pom.xml"),
			Path("/user/home/root/module-1/pom.xml"),
			Path("/user/home/root/module-1/src/test/java/com/example/ExampleTest.java"),
			Path("/user/home/root/module-2/pom.xml"),
			Path("/user/home/root/module-2/src/test/java/com/example/ExampleInSecondModuleTest.java"),
		}
		local expected_base_dir = Path("/user/home/root/module-2")

		-- when
		local spec_builder_instance = SpecBuilder({
			mkdir = function() end,

			scan = function()
				return project_paths
			end,
			compile = function(base_dir)
				assert(
					base_dir == expected_base_dir,
					"should compile with the expected_base_dir: "
						.. vim.inspect({ actual = base_dir:to_string(), expected = expected_base_dir:to_string() })
				)
			end,
			classpath_provider = {
				get_classpath = function()
					return "classpath-file-argument"
				end,
			},
			report_folder_name_gen = function()
				return Path("report_folder")
			end,
			build_tool_getter = function()
				--- @type neotest-java.BuildTool
				return FakeBuildTool
			end,
			detect_project_type = function()
				return "maven"
			end,
			binaries = {
				java = function()
					return Path("java")
				end,
			},
		})
		local actual = spec_builder_instance.build_spec(args, test_config)

		-- then
		eq({
			command = vim.iter({
				"java",
				"-Duser.dir=" .. Path("/user/home/root/module-2"):to_string(),
				"-Dspring.config.additional-location=" .. Path("src/main/resources/application.properties"):to_string(),
				"-jar",
				"my-junit-jar.jar",
				"execute",
				"--classpath=classpath-file-argument",
				"--reports-dir=report_folder",
				"--fail-if-no-tests",
				"--disable-banner",
				"--details=testfeed",
				"--config=junit.platform.output.capture.stdout=true",
				"--config=junit.platform.output.capture.stderr=true",
				"--exclude-engine=archunit",
				"--select-method='com.example.ExampleInSecondModuleTest#shouldNotFail()'",
			}):join(" "),
			context = {
				reports_dir = Path("report_folder"),
			},
			cwd = Path("/user/home/root/module-2"):to_string(),
			symbol = "shouldNotFail",
		}, actual)
	end)

	it("uses module.base_dir (not filepath:parent()) when resolving java binary for a dir position", function()
		-- Regression test: when position.type == "dir" and position.path is the module
		-- directory itself, filepath:parent() resolves to the repo root, which jdtls
		-- does not own as a project and rejects with -32001.  The fix is to always
		-- resolve the java binary using module.base_dir.
		local module_dir = Path("/user/home/root/module-2")
		local tree = Tree.from_list({
			id = module_dir:to_string(),
			name = module_dir:name(),
			path = module_dir:to_string(),
			type = "dir",
		}, function(x)
			return x
		end)

		local project_paths = {
			Path("/user/home/root"),
			Path("/user/home/root/pom.xml"),
			Path("/user/home/root/module-1/pom.xml"),
			Path("/user/home/root/module-1/src/test/java/com/example/ExampleTest.java"),
			Path("/user/home/root/module-2/pom.xml"),
			Path("/user/home/root/module-2/src/test/java/com/example/ExampleInSecondModuleTest.java"),
		}

		local captured_binaries_cwd = nil

		local spec_builder_instance = SpecBuilder({
			mkdir = function() end,

			scan = function()
				return project_paths
			end,
			compile = function() end,
			classpath_provider = {
				get_classpath = function()
					return "classpath-file-argument"
				end,
			},
			report_folder_name_gen = function()
				return Path("report_folder")
			end,
			build_tool_getter = function()
				return FakeBuildTool
			end,
			detect_project_type = function()
				return "maven"
			end,
			binaries = {
				java = function(cwd)
					captured_binaries_cwd = cwd
					return Path("java")
				end,
			},
		})

		-- The tree has no test children so build_spec will error at the selector
		-- validation step — that's fine, we only care that binaries.java() was
		-- called with the correct cwd before that point.
		pcall(spec_builder_instance.build_spec, { tree = tree, strategy = "integration" }, config)

		assert(captured_binaries_cwd ~= nil, "binaries.java() should have been called")
		eq(
			module_dir,
			captured_binaries_cwd,
			"binaries.java() should be called with module.base_dir, not filepath:parent() (which would be the repo root)"
		)
	end)

	it("builds spec for debug test (dap strategy)", function()
		-- Mock dap module to avoid error
		package.loaded["dap"] = {}

		local tree = Tree.from_list({
			id = "com.example.ExampleTest#shouldNotFail()",
			path = "/user/home/root/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		}, function(x)
			return x
		end)
		-- Add ref method to the tree node
		local position = tree:data()
		local node = tree:get_key(position.id)
		if node then
			local node_data = node:data()
			node_data.ref = function()
				return position.id
			end
		else
			-- If node is not found, add ref directly to position via metatable
			local mt = getmetatable(position) or {}
			local original_index = mt.__index
			mt.__index = function(t, k)
				if k == "ref" then
					return function()
						return position.id
					end
				end
				if original_index then
					return original_index(t, k)
				end
			end
			setmetatable(position, mt)
		end

		local test_config = {
			junit_jar = Path("my-junit-jar.jar"),
		}
		local project_paths = {
			Path("."),
			Path("./src/test/java/com/example/ExampleTest.java"),
			Path("./pom.xml"),
		}

		-- Mock launch_debug_test
		local mock_terminated_event = { mock = "event" }
		local launch_debug_test_called = false
		local launch_debug_test_args = {}
		local captured_port = nil

		local launch_debug_test = function(command, args, cwd)
			launch_debug_test_called = true
			launch_debug_test_args = { command = command, args = args, cwd = cwd }
			-- Extract port from debug agent arguments
			for _, arg in ipairs(args) do
				local port_match = string.match(arg, "address=0%.0%.0%.0:(%d+)")
				if port_match then
					captured_port = tonumber(port_match)
				end
			end
			return mock_terminated_event
		end

		-- when
		local spec_builder_instance = SpecBuilder({
			mkdir = function() end,

			scan = function(_base_dir, opts)
				opts = opts or {}
				if opts.search_patterns and opts.search_patterns[1] == Path("test/resources$"):to_string() then
					return { Path("additional1"), Path("additional2") }
				end

				return project_paths
			end,
			compile = function(base_dir)
				assert(
					base_dir == Path("."),
					"should compile with the project root as base_dir: "
						.. vim.inspect({ actual = base_dir:to_string(), expected = Path("."):to_string() })
				)
			end,
			classpath_provider = {
				get_classpath = function(base_dir, additional_classpaths)
					eq(Path("."), base_dir)
					eq({ Path("additional1"), Path("additional2") }, additional_classpaths)

					return "classpath-file-argument"
				end,
			},
			report_folder_name_gen = function(module_dir, build_dir)
				eq(Path("."), module_dir)
				eq(Path("target"), build_dir)

				return Path("report_folder")
			end,
			build_tool_getter = function()
				--- @type neotest-java.BuildTool
				return FakeBuildTool
			end,
			detect_project_type = function()
				return "maven"
			end,
			binaries = {
				java = function()
					return Path("java")
				end,
			},
			launch_debug_test = launch_debug_test,
		})
		local actual = spec_builder_instance.build_spec({ tree = tree, strategy = "dap" }, test_config)

		-- then
		assert(launch_debug_test_called, "launch_debug_test should be called")
		eq("java", launch_debug_test_args.command)
		eq(Path("."), launch_debug_test_args.cwd)
		assert(captured_port ~= nil, "port should be captured from debug agent arguments")
		assert(
			vim.iter(launch_debug_test_args.args):any(function(arg)
				return string.find(arg, "-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=0%.0%.0%.0:")
					~= nil
			end),
			"launch_debug_test should be called with debug agent arguments"
		)
		assert(
			vim.iter(launch_debug_test_args.args):any(function(arg)
				return arg == "-Xdebug"
			end),
			"launch_debug_test should be called with -Xdebug argument"
		)

		assert(actual.strategy ~= nil, "result should have strategy field")
		eq("java", actual.strategy.type)
		eq("attach", actual.strategy.request)
		eq("localhost", actual.strategy.host)
		eq(captured_port, actual.strategy.port)
		eq(("neotest-java (on port %s)"):format(captured_port), actual.strategy.name)
		eq(Path("."):name(), actual.strategy.projectName)
		eq(Path("."):to_string(), actual.cwd)
		eq("shouldNotFail", actual.symbol)
		eq("dap", actual.context.strategy)
		eq(Path("report_folder"), actual.context.reports_dir)
		eq(mock_terminated_event, actual.context.terminated_command_event)
	end)
end)
