local async = require("nio").tests
local plugin = require("neotest-java")
local buildtools = require("neotest-java.buildtools")

local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")

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
	before_each(function()
		-- set config
		---@class neotest-java.Config
		local config = {
			ignore_wrapper = false,
			buildtools = {
				buildtools.gradle,
				buildtools.maven,
			},
		}
		plugin.config = config
	end)

	async.it("builds spec for one method in unit test class with maven", function()
		local args = mock_args_tree({
			path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		})

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "./mvnw test -Dtest=com.example.ExampleTest#shouldNotFail"
		local expected_cwd = current_dir .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = buildtools.maven,
			test_class_names = { "com.example.ExampleTest" },
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("builds spec for one method in unit test class with gradle", function()
		local args = mock_args_tree({
			path = current_dir .. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java",
			name = "shouldNotFail",
			type = "test",
		})

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "./gradlew test --tests com.example.ExampleTest.shouldNotFail"
		local expected_cwd = current_dir .. "tests/fixtures/gradle-groovy-demo"
		local expected_context = {
			project_type = buildtools.gradle,
			test_class_names = { "com.example.ExampleTest" },
			test_method_names = { "shouldNotFail" },
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expected_context, actual.context)
	end)

	async.it("builds the spec for unit test class with maven", function()
		local args = mock_args_tree({
			path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java",
			name = "ExampleTest",
			type = "file",
		})

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "./mvnw test -Dtest=com.example.ExampleTest"
		local expected_cwd = current_dir .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = buildtools.maven,
			test_class_names = { "com.example.ExampleTest" },
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("builds the spec for dirs with gradle", function()
		local path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/"
		local args = mock_args_tree({
			path = path,
			type = "dir",
		})

		-- mock iter()
		local positions = {
			{
				type = "file",
				name = "ExampleTest.java",
				path = path .. "ExampleTest.java",
			},
			{
				type = "file",
				name = "NestedTests.java",
				path = path .. "NestedTests.java",
			},
		}

		local i = 0
		args.tree.iter = function()
			return function()
				i = i + 1
				if positions[i] == nil then
					return nil
				end
				return i, positions[i]
			end
		end

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "./mvnw test -Dtest=com.example.ExampleTest,com.example.NestedTests"
		local expected_cwd = current_dir .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			-- <<<<<<< HEAD
			project_type = buildtools.maven,
			-- test_class_names = { "com.example.SumTest", "com.example.SecondTest" },
			-- =======
			-- project_type = "maven",
			test_class_names = { "com.example.ExampleTest", "com.example.NestedTests" },
			-- >>>>>>> main
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
						path = current_dir
							.. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java",
						name = "ExampleTest.java",
						type = "file",
					}
				end,
				children = function()
					return {
						{
							data = function()
								return {
									path = current_dir
										.. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java",
									name = "firstTest",
									type = "test",
								}
							end,
						},
						{
							data = function()
								return {
									path = current_dir
										.. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java",
									name = "secondTest",
									type = "test",
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
		local expected_cwd = current_dir .. "tests/fixtures/gradle-groovy-demo"
		local expeceted_context = {
			project_type = buildtools.gradle,
			test_class_names = { "com.example.ExampleTest" },
			test_method_names = { "firstTest", "secondTest" },
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("builds the spec for method in integration test class with maven", function()
		local args = mock_args_tree({
			path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java",
			name = "shouldWorkProperly",
			type = "test",
		})

		-- when
		local actual = plugin.build_spec(args)

		local expected_command = "./mvnw verify -Dtest=com.example.demo.RepositoryIT#shouldWorkProperly"
		local expected_cwd = current_dir .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = buildtools.maven,
			test_class_names = { "com.example.demo.RepositoryIT" },
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)

	async.it("should ignore the wrapper", function()
		local args = mock_args_tree({
			path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java",
			name = "ExampleTest",
			type = "test",
		})

		-- config
		plugin.config.ignore_wrapper = true

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_command = "mvn test -Dtest=com.example.ExampleTest#ExampleTest"
		local expected_cwd = current_dir .. "tests/fixtures/maven-demo"
		local expeceted_context = {
			project_type = buildtools.maven,
			test_class_names = { "com.example.ExampleTest" },
			test_method_names = {},
		}

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
		assert.are.same(expeceted_context, actual.context)
	end)
end)
