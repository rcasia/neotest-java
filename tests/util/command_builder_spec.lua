---@diagnostic disable: undefined-field
local command_builder = require("neotest-java.util.command_builder")

describe("command_builder", function()
	it("builds command for unit test", function()
		local command = command_builder:new()

		command:project_type("maven")
		command:ignore_wrapper(false)
		command:is_integration_test(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", "shouldNotFail", "test")

		assert.are.equal("./mvnw test -Dtest=com.example.ExampleTest#shouldNotFail", command:build())
	end)

	it("builds command for integration test", function()
		local command = command_builder:new()

		command:project_type("maven")
		command:ignore_wrapper(false)
		command:is_integration_test(true)
		command:test_reference("src/test/java/com/example/ExampleIT.java", "shouldNotFail", "test")

		assert.are.equal("./mvnw verify -Dtest=com.example.ExampleIT#shouldNotFail", command:build())
	end)

	it("builds command for unit test with gradle", function()
		local command = command_builder:new()

		command:project_type("gradle")
		command:ignore_wrapper(false)
		command:is_integration_test(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", "shouldNotFail", "test")

		assert.are.equal("./gradlew test --tests com.example.ExampleTest.shouldNotFail", command:build())
	end)

	it("builds command for integration test with gradle", function()
		local command = command_builder:new()

		command:project_type("gradle")
		command:ignore_wrapper(false)
		command:is_integration_test(true)
		command:test_reference("src/test/java/com/example/ExampleIT.java", "shouldNotFail", "test")

		assert.are.equal("./gradlew test --tests com.example.ExampleIT.shouldNotFail", command:build())
	end)

	it("builds command for test files", function()
		local command = command_builder:new()

		command:project_type("gradle")
		command:ignore_wrapper(false)
		command:is_integration_test(false)
		command:test_reference("src/test/java/com/example/ExampleTest", nil, "file")

		assert.are.equal("./gradlew test --tests com.example.ExampleTest", command:build())
	end)

	it("adds multiple test references for gradle", function()
		local command = command_builder:new()

		command:project_type("gradle")
		command:ignore_wrapper(false)
		command:is_integration_test(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", nil, "dir")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", nil, "dir")

		assert.are.equal(
			"./gradlew test --tests com.example.ExampleTest --tests com.example.SecondExampleTest",
			command:build()
		)
	end)

	it("add multiple test references for maven", function()
		local command = command_builder:new()

		command:project_type("maven")
		command:ignore_wrapper(false)
		command:is_integration_test(false)
		command:test_reference("src/test/java/com/example/ExampleTest.java", nil, "dir")
		command:test_reference("src/test/java/com/example/SecondExampleTest.java", nil, "dir")

		assert.are.equal("./mvnw test -Dtest=com.example.ExampleTest,com.example.SecondExampleTest", command:build())
	end)
end)
