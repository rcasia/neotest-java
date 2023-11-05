local async = require("plenary.async").tests
local plugin = require("neotest-java")
local Tree = require("neotest.types.tree")

local function getCurrentDir()
	return vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
end

describe("SpecBuilder", function()
	before_each(function()
		-- set config
		local config = {
			ignore_wrapper = false,
		}
		plugin.config = config
	end)

	async.it("builds spec for one method in unit test class with maven", function()
		local path = getCurrentDir() .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"

		local args = {
			tree = {
				data = function()
					return {
						path = path,
						name = "shouldNotFail",
					}
				end,
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_position = "com.example.ExampleTest#shouldNotFail"

		local expected_command = "./mvnw test -Dtest=" .. expected_position
		local expected_cwd = getCurrentDir() .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = "maven",
			test_class_path = "com.example.ExampleTest",
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("builds spec for one method in unit test class with gradle", function()
		local path = getCurrentDir() .. "tests/fixtures/gradle-demo/src/test/java/com/example/ExampleTest.java"

		local args = {
			tree = {
				data = function()
					return {
						path = path,
						name = "shouldNotFail",
					}
				end,
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "./gradlew test --tests com.example.ExampleTest.shouldNotFail"
		local expected_cwd = getCurrentDir() .. "tests/fixtures/gradle-demo"
		local expeceted_context = {
			project_type = "gradle",
			test_class_path = "com.example.ExampleTest",
			test_method_names = { "shouldNotFail" },
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("builds the spec for unit test class with maven", function()
		local args = {
			tree = {
				data = function()
					return {
						path = getCurrentDir()
							.. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java",
						name = "ExampleTest",
					}
				end,
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_position = "com.example.ExampleTest#ExampleTest"

		local expected_command = "./mvnw test -Dtest=" .. expected_position
		local expected_cwd = getCurrentDir() .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = "maven",
			test_class_path = "com.example.ExampleTest",
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("builds the spec for unit test class with maven", function()
		local args = {
			tree = {
				data = function()
					return {
						path = getCurrentDir()
							.. "tests/fixtures/gradle-demo/src/test/java/com/example/ExampleTest.java",
						name = "ExampleTest.java",
					}
				end,
				children = function()
					return {
						{
							data = function()
								return {
									path = getCurrentDir()
										.. "tests/fixtures/gradle-demo/src/test/java/com/example/ExampleTest.java",
									name = "firstTest",
								}
							end,
						},
						{
							data = function()
								return {
									path = getCurrentDir()
										.. "tests/fixtures/gradle-demo/src/test/java/com/example/ExampleTest.java",
									name = "secondTest",
								}
							end,
						},
					}
				end,
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "./gradlew test --tests com.example.ExampleTest"
		local expected_cwd = getCurrentDir() .. "tests/fixtures/gradle-demo"
		local expeceted_context = {
			project_type = "gradle",
			test_class_path = "com.example.ExampleTest",
			test_method_names = { "firstTest", "secondTest" },
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("builds the spec for method in integration test class with maven", function()
		local args = {
			tree = {
				data = function()
					return {
						path = getCurrentDir()
							.. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java",
						name = "shouldWorkProperly",
					}
				end,
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		local expected_command = "./mvnw verify -Dtest=com.example.demo.RepositoryIT#shouldWorkProperly"
		local expected_cwd = getCurrentDir() .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = "maven",
			test_class_path = "com.example.demo.RepositoryIT",
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("should ignore the wrapper", function()
		local args = {
			tree = {
				data = function()
					return {
						path = getCurrentDir()
							.. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java",
						name = "ExampleTest",
					}
				end,
			},
			extra_args = {},
		}

		-- config
		plugin.config.ignore_wrapper = true

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_position = "com.example.ExampleTest#ExampleTest"

		local expected_command = "mvn test -Dtest=" .. expected_position
		local expected_cwd = getCurrentDir() .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = "maven",
			test_class_path = "com.example.ExampleTest",
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)
end)
