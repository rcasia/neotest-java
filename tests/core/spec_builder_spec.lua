local async = require("plenary.async").tests
local plugin = require("neotest-java")
local Tree = require("neotest.types.tree")

local function getCurrentDir()
	return vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
end

describe("SpecBuilder", function()
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

		local expected_command = "mvn clean test -Dtest=" .. expected_position
		local expected_cwd = getCurrentDir() .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = "maven",
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
		local expected_command = "gradle clean test --tests com.example.ExampleTest.shouldNotFail"
		local expected_cwd = getCurrentDir() .. "tests/fixtures/gradle-demo"
		local expeceted_context = {
			project_type = "gradle",
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

		local expected_command = "mvn clean test -Dtest=" .. expected_position
		local expected_cwd = getCurrentDir() .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = "maven",
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
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "gradle clean test --tests com.example.ExampleTest"
		local expected_cwd = getCurrentDir() .. "tests/fixtures/gradle-demo"
		local expeceted_context = {
			project_type = "gradle",
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

		local expected_command = "mvn clean verify -Dtest=com.example.demo.RepositoryIT#shouldWorkProperly"
		local expected_cwd = getCurrentDir() .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = "maven",
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)
end)
