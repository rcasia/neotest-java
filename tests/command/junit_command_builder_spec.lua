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
		local command = command_builder:new({ junit_jar = "junit-jar-filepath" })

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "test")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")
		command:reports_dir("/reports/dir")

		assert.are.equal(
			"javac "
				.. "-d target/neotest-java/test-classes "
				.. "-cp target/neotest-java/test-classes:[classpath-mock]:junit-jar-filepath "
				.. "./src/test/java/com/example/ExampleApplicationTests.java "
				.. "&& "
				.. "java "
				.. "-jar junit-jar-filepath "
				.. "execute "
				.. "-cp target/neotest-java/test-classes:[classpath-mock]:junit-jar-filepath "
				.. "-m=com.example.ExampleTest#shouldNotFail "
				.. "--fail-if-no-tests "
				.. "--reports-dir=/reports/dir",
			command:build()
		)
	end)

	it("builds command for dir", function()
		local command = command_builder:new({ junit_jar = "junit-jar-filepath" })

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "dir")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")
		command:reports_dir("/reports/dir")

		assert.are.equal(
			"javac "
				.. "-d target/neotest-java/test-classes "
				.. "-cp target/neotest-java/test-classes:[classpath-mock]:junit-jar-filepath "
				.. "./src/test/java/com/example/ExampleApplicationTests.java "
				.. "&& "
				.. "java "
				.. "-jar junit-jar-filepath "
				.. "execute "
				.. "-cp target/neotest-java/test-classes:[classpath-mock]:junit-jar-filepath "
				.. "-p=com.example "
				.. "--fail-if-no-tests "
				.. "--reports-dir=/reports/dir",
			command:build()
		)
	end)

	it("builds command for file", function()
		local command = command_builder:new({ junit_jar = "junit-jar-filepath" })

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "file")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")
		command:reports_dir("/reports/dir")

		assert.are.equal(
			"javac "
				.. "-d target/neotest-java/test-classes "
				.. "-cp target/neotest-java/test-classes:[classpath-mock]:junit-jar-filepath "
				.. "./src/test/java/com/example/ExampleApplicationTests.java "
				.. "&& "
				.. "java "
				.. "-jar junit-jar-filepath "
				.. "execute "
				.. "-cp target/neotest-java/test-classes:[classpath-mock]:junit-jar-filepath "
				.. "-c=com.example.ExampleTest "
				.. "--fail-if-no-tests "
				.. "--reports-dir=/reports/dir",
			command:build()
		)
	end)
end)
