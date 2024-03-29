---@diagnostic disable: undefined-field
local command_builder = require("neotest-java.command.junit_command_builder")

describe("junit command_builder", function()
	-- mock
	local handle = {
		read = function(self, string)
			return "[classpath-mock]"
		end,
		close = function(self) end,
	}
	io.popen = function(str)
		return handle
	end

	it("builds command for unit test", function()
		local command = command_builder:new()

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "test")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")

		assert.are.equal(
			"javac "
				.. "-d target "
				.. "-cp ./target/classes/:./target/test-classes/:[classpath-mock]:/home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "./src/test/java/com/example/ExampleApplicationTests.java "
				.. "&& "
				.. "java "
				.. "-jar /home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "execute "
				.. "-cp ./target/classes/:./target/test-classes/:[classpath-mock]:/home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "-m=com.example.ExampleTest#shouldNotFail "
				.. "--fail-if-no-tests "
				.. "--reports-dir=/tmp/neotest-java",
			command:build()
		)
	end)

	it("builds command for dir", function()
		local command = command_builder:new()

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "dir")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")

		assert.are.equal(
			"javac "
				.. "-d target "
				.. "-cp ./target/classes/:./target/test-classes/:[classpath-mock]:/home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "./src/test/java/com/example/ExampleApplicationTests.java "
				.. "&& "
				.. "java "
				.. "-jar /home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "execute "
				.. "-cp ./target/classes/:./target/test-classes/:[classpath-mock]:/home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "-p=com.example "
				.. "--fail-if-no-tests "
				.. "--reports-dir=/tmp/neotest-java",
			command:build()
		)
	end)

	it("builds command for file", function()
		local command = command_builder:new()

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "file")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")

		assert.are.equal(
			"javac "
				.. "-d target "
				.. "-cp ./target/classes/:./target/test-classes/:[classpath-mock]:/home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "./src/test/java/com/example/ExampleApplicationTests.java "
				.. "&& "
				.. "java "
				.. "-jar /home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "execute "
				.. "-cp ./target/classes/:./target/test-classes/:[classpath-mock]:/home/rico/Downloads/junit-platform-console-standalone-1.10.1.jar "
				.. "-c=com.example.ExampleTest "
				.. "--fail-if-no-tests "
				.. "--reports-dir=/tmp/neotest-java",
			command:build()
		)
	end)
end)
