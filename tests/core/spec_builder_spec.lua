local SpecBuilder = require("neotest-java.core.spec_builder")
local Path = require("neotest-java.util.path")
local FakeBuildTool = require("tests.fake_build_tool")

local eq = assert.are.same

local function mock_args_tree(data)
	return {
		tree = {
			data = function()
				return data
			end,
		},
		extra_args = {},
	}
end

describe("SpecBuilder", function()
	it("builds spec for one method", function()
		local args = mock_args_tree({
			id = "com.example.ExampleTest#shouldNotFail()",
			path = "/user/home/root/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		})
		local config = {
			junit_jar = Path("my-junit-jar.jar"),
		}
		local project_paths = {
			Path("."),
			Path("./src/test/java/com/example/ExampleTest.java"),
			Path("./pom.xml"),
		}

		-- when
		local actual = SpecBuilder.build_spec(args, config, {
			mkdir = function() end,
			chdir = function() end,
			root_getter = function()
				return Path("root")
			end,
			scan = function()
				return project_paths
			end,
			compile = function(base_dir)
				local expected_base_dir = Path(".")
				assert(
					base_dir == Path("."),
					"should compile with the project root as base_dir: "
						.. vim.inspect({ actual = base_dir.to_string(), expected = expected_base_dir.to_string() })
				)
				return "classpath-file-argument"
			end,
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
		})

		-- then
		eq({
			command = vim.iter({
				"java",
				"-Dspring.config.additional-location=" .. Path("src/main/resources/application.properties").to_string(),
				"-jar",
				"my-junit-jar.jar",
				"execute",
				"--classpath=classpath-file-argument",
				"--reports-dir=report_folder",
				"--fail-if-no-tests",
				"--disable-banner",
				"--details=testfeed",
				"--config=junit.platform.output.capture.stdout=true",
				"--select-class='com.example.ExampleTest'",
				"--select-method='com.example.ExampleTest#shouldNotFail()'",
			}):join(" "),
			context = {
				reports_dir = Path("report_folder"),
			},
			cwd = "root",
			symbol = "shouldNotFail",
		}, actual)
	end)

	it("builds spec for one method with extra args", function()
		local args = mock_args_tree({
			id = "com.example.ExampleTest#shouldNotFail()",
			path = "/user/home/root/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		})
		local config = {
			junit_jar = Path("my-junit-jar.jar"),
			jvm_args = { "-myExtraJvmArg" },
		}
		local project_paths = {
			Path("/user/home/root"),
			Path("/user/home/root/src/test/java/com/example/ExampleTest.java"),
			Path("/user/home/root/pom.xml"),
		}

		-- when
		local actual = SpecBuilder.build_spec(args, config, {
			mkdir = function() end,
			chdir = function() end,
			root_getter = function()
				return Path("root")
			end,
			scan = function()
				return project_paths
			end,
			compile = function()
				return "classpath-file-argument"
			end,
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
		})

		-- then
		eq({
			command = vim.iter({
				"java",
				"-Dspring.config.additional-location=" .. Path("src/main/resources/application.properties").to_string(),
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
				"--select-class='com.example.ExampleTest'",
				"--select-method='com.example.ExampleTest#shouldNotFail()'",
			}):join(" "),
			context = {
				reports_dir = Path("report_folder"),
			},
			cwd = "root",
			symbol = "shouldNotFail",
		}, actual)
	end)

	it("builds spec for one method in a multi-module project", function()
		local args = mock_args_tree({
			id = "com.example.ExampleInSecondModuleTest#shouldNotFail()",
			path = "/user/home/root/module-2/src/test/java/com/example/ExampleInSecondModuleTest.java",
			name = "shouldNotFail",
			type = "test",
		})
		local config = {
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
		local actual = SpecBuilder.build_spec(args, config, {
			mkdir = function() end,
			chdir = function() end,
			root_getter = function()
				return Path("root")
			end,
			scan = function()
				return project_paths
			end,
			compile = function(base_dir)
				assert(
					base_dir == expected_base_dir,
					"should compile with the expected_base_dir: "
						.. vim.inspect({ actual = base_dir.to_string(), expected = expected_base_dir.to_string() })
				)
				return "classpath-file-argument"
			end,
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
		})

		-- then
		eq({
			command = vim.iter({
				"java",
				"-Dspring.config.additional-location=" .. Path("src/main/resources/application.properties").to_string(),
				"-jar",
				"my-junit-jar.jar",
				"execute",
				"--classpath=classpath-file-argument",
				"--reports-dir=report_folder",
				"--fail-if-no-tests",
				"--disable-banner",
				"--details=testfeed",
				"--config=junit.platform.output.capture.stdout=true",
				"--select-class='com.example.ExampleInSecondModuleTest'",
				"--select-method='com.example.ExampleInSecondModuleTest#shouldNotFail()'",
			}):join(" "),
			context = {
				reports_dir = Path("report_folder"),
			},
			cwd = "root",
			symbol = "shouldNotFail",
		}, actual)
	end)
end)
