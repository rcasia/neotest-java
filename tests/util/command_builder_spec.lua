---@diagnostic disable: undefined-field
local command_builder = require("neotest-java.util.command_builder")
local buildtools = require("neotest-java.buildtools")

describe("command_builder", function()
	it("builds command for unit test", function()
		local command = command_builder:new()

		command:project_type(buildtools.maven)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", "shouldNotFail", "test")

		assert.are.equal("./mvnw test -Dtest=com.example.ExampleTest#shouldNotFail", command:build())
	end)

	it("builds command for integration test", function()
		local command = command_builder:new()

		command:project_type(buildtools.maven)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleIT.java", "shouldNotFail", "test")

		assert.are.equal("./mvnw verify -Dtest=com.example.ExampleIT#shouldNotFail", command:build())
	end)

	it("builds command for unit test with gradle", function()
		local command = command_builder:new()

		command:project_type(buildtools.gradle)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", "shouldNotFail", "test")

		assert.are.equal("./gradlew test --tests com.example.ExampleTest.shouldNotFail", command:build())
	end)

	it("builds command for integration test with gradle", function()
		local command = command_builder:new()

		command:project_type(buildtools.gradle)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleIT.java", "shouldNotFail", "test")

		assert.are.equal("./gradlew test --tests com.example.ExampleIT.shouldNotFail", command:build())
	end)

	it("builds command for test files", function()
		local command = command_builder:new()

		command:project_type(buildtools.gradle)
		command:ignore_wrapper(false)
		command:test_reference("project_root/src/test/java/com/example/ExampleTest", nil, "file")

		assert.are.equal("./gradlew test --tests com.example.ExampleTest", command:build())
	end)

	it("adds multiple test references for gradle", function()
		local command = command_builder:new()

		command:project_type(buildtools.gradle)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", nil, "dir")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", nil, "dir")

		assert.are.equal(
			"./gradlew test --tests com.example.ExampleTest --tests com.example.SecondExampleTest",
			command:build()
		)
	end)

	it("add multiple test references for maven", function()
		local command = command_builder:new()

		command:project_type(buildtools.maven)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", nil, "dir")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", nil, "dir")

		assert.are.equal("./mvnw test -Dtest=com.example.ExampleTest,com.example.SecondExampleTest", command:build())
	end)

	it("gives the referenced classes", function()
		local command = command_builder:new()

		command:project_type(buildtools.maven)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", "shouldPass", "test")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", "shouldFail", "test")

		assert.are.same(
			{ "com.example.ExampleTest", "com.example.SecondExampleTest" },
			command:get_referenced_classes()
		)
	end)

	it("gives the referenced methods", function()
		local command = command_builder:new()

		command:project_type(buildtools.maven)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", "shouldPass", "test")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", "shouldFail", "test")

		assert.are.same(
			{ "com.example.ExampleTest#shouldPass", "com.example.SecondExampleTest#shouldFail" },
			command:get_referenced_methods()
		)
	end)

	it("gives the refenced method names", function()
		local command = command_builder:new()

		command:project_type(buildtools.maven)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", "shouldPass", "test")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", "shouldFail", "test")

		assert.are.same({ "shouldPass", "shouldFail" }, command:get_referenced_method_names())
	end)

	it("should be able to detect if contains any integration test", function()
		local command = command_builder:new()

		command:project_type(buildtools.maven)
		command:ignore_wrapper(false)
		command:test_reference("src/test/java/com/example/ExampleTestIT.java", "shouldPass", "test")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", "shouldFail", "test")

		assert.are.same(true, command:contains_integration_tests())
	end)
end)
