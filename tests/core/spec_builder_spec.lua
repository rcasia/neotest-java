local SpecBuilder = require("neotest-java.core.spec_builder")

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
			junit_jar = "my-junit-jar.jar",
		}
		local project_type = "maven"
		local project_paths = {
			"/user/home/root",
			"/user/home/root/src/test/java/com/example/ExampleTest.java",
			"/user/home/root/pom.xml",
		}

		-- when
		local actual = SpecBuilder.build_spec(args, project_type, config, {
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
		})

		-- then
		assert.are.same({
			command = "java -Dspring.config.additional-location=optional:file:/user/home/target/classes/classes/application.yml,optional:file:/user/home/target/classes/classes/application.yaml,optional:file:/user/home/target/classes/classes/application.properties,optional:file:/user/home/target/classes/classes/application-test.yml,optional:file:/user/home/target/classes/classes/application-test.yaml,optional:file:/user/home/target/classes/classes/application-test.properties,optional:file:/user/home/target/classes/test-classes/application.yml,optional:file:/user/home/target/classes/test-classes/application.yaml,optional:file:/user/home/target/classes/test-classes/application.properties,optional:file:/user/home/target/classes/test-classes/application-test.yml,optional:file:/user/home/target/classes/test-classes/application-test.yaml,optional:file:/user/home/target/classes/test-classes/application-test.properties,optional:file:/user/home/root/src/test/java/com/example/target/classes/classes/application.yml,optional:file:/user/home/root/src/test/java/com/example/target/classes/classes/application.yaml,optional:file:/user/home/root/src/test/java/com/example/target/classes/classes/application.properties,optional:file:/user/home/root/src/test/java/com/example/target/classes/classes/application-test.yml,optional:file:/user/home/root/src/test/java/com/example/target/classes/classes/application-test.yaml,optional:file:/user/home/root/src/test/java/com/example/target/classes/classes/application-test.properties,optional:file:/user/home/root/src/test/java/com/example/target/classes/test-classes/application.yml,optional:file:/user/home/root/src/test/java/com/example/target/classes/test-classes/application.yaml,optional:file:/user/home/root/src/test/java/com/example/target/classes/test-classes/application.properties,optional:file:/user/home/root/src/test/java/com/example/target/classes/test-classes/application-test.yml,optional:file:/user/home/root/src/test/java/com/example/target/classes/test-classes/application-test.yaml,optional:file:/user/home/root/src/test/java/com/example/target/classes/test-classes/application-test.properties,optional:file:/user/home/root/target/classes/classes/application.yml,optional:file:/user/home/root/target/classes/classes/application.yaml,optional:file:/user/home/root/target/classes/classes/application.properties,optional:file:/user/home/root/target/classes/classes/application-test.yml,optional:file:/user/home/root/target/classes/classes/application-test.yaml,optional:file:/user/home/root/target/classes/classes/application-test.properties,optional:file:/user/home/root/target/classes/test-classes/application.yml,optional:file:/user/home/root/target/classes/test-classes/application.yaml,optional:file:/user/home/root/target/classes/test-classes/application.properties,optional:file:/user/home/root/target/classes/test-classes/application-test.yml,optional:file:/user/home/root/target/classes/test-classes/application-test.yaml,optional:file:/user/home/root/target/classes/test-classes/application-test.properties -jar my-junit-jar.jar execute --classpath=classpath-file-argument --reports-dir=report_folder --fail-if-no-tests --disable-banner --details=testfeed --config=junit.platform.output.capture.stdout=true --select-class='com.example.ExampleTest' --select-method='com.example.ExampleTest'",
			context = {
				reports_dir = "report_folder",
			},
			cwd = "root",
			symbol = "shouldNotFail",
		}, actual)
	end)
end)
