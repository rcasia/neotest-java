local SpecBuilder = require("neotest-java.core.spec_builder")
local Path = require("neotest-java.util.path")

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
	it("builds spec for one method in unit test class with maven", function()
		local args = mock_args_tree({
			id = "com.example.ExampleTest",
			path = "/user/home/root/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		})
		local config = {
			junit_jar = Path("my-junit-jar.jar"),
		}
		local project_paths = {
			"/user/home/root",
			"/user/home/root/src/test/java/com/example/ExampleTest.java",
			"/user/home/root/pom.xml",
		}

		-- when
		local actual = SpecBuilder.build_spec(args, config, {
			mkdir = function() end,
			chdir = function() end,
			root_getter = function()
				return "root"
			end,
			scan = function()
				return project_paths
			end,
			compile = function()
				return "classpath-file-argument"
			end,
			report_folder_name_gen = function()
				return "report_folder"
			end,
			build_tool_getter = function()
				--- @type neotest-java.BuildTool
				return {
					get_output_dir = function()
						return "/user/home/target"
					end,
					get_module_dependencies = function()
						return {}
					end,
					get_project_filename = function()
						return "pom.xml"
					end,
					get_spring_property_filepaths = function()
						return {}
					end,

					get_classpaths = function()
						return {
							"/user/home/target/classes",
							"/user/home/target/test-classes",
						}
					end,
				}
			end,
			detect_project_type = function()
				return "maven"
			end,
		})

		-- then
		assert.are.same({
			command = "java -Dspring.config.additional-location= -jar my-junit-jar.jar execute --classpath=classpath-file-argument --reports-dir=report_folder --fail-if-no-tests --disable-banner --details=testfeed --config=junit.platform.output.capture.stdout=true --select-class='com.example.ExampleTest' --select-method='com.example.ExampleTest'",
			context = {
				reports_dir = "report_folder",
			},
			cwd = "root",
			symbol = "shouldNotFail",
		}, actual)
	end)
end)
