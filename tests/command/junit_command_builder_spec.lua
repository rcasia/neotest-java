---@diagnostic disable: undefined-field
local command_builder = require("neotest-java.command.junit_command_builder")

describe("junit command_builder", function()
	-- mock
	require("neotest.lib.process").run = function(str)
		return 0, { stdout = "stdout", stderr = "stderr" }
		-- do nothing
	end

	io.open = function(filepath, mode)
		return {
			write = function(self, content)
				-- do nothing
			end,
			close = function(self) end,
		}
	end

	it("builds command for unit test", function()
		local command = command_builder:new({ junit_jar = "junit-jar-filepath" }, "maven")

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "test")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")
		command:reports_dir("/reports/dir")

		assert.are.equal(
			([[javac 
      -d target/neotest-java/classes
      -cp $(cat target/neotest-java/classpath.txt)
      src/main/**/*.java 
      &&
      javac 
      -d target/neotest-java/classes
      -cp $(cat target/neotest-java/classpath.txt):target/neotest-java/classes 
      src/test/**/*.java
      && 
      java 
      -jar junit-jar-filepath 
      execute 
      -cp $(cat target/neotest-java/classpath.txt):target/neotest-java/classes
      -m=com.example.ExampleTest#shouldNotFail
      --fail-if-no-tests 
      --reports-dir=/reports/dir]]):gsub("\n", ""):gsub("%s+", " "),
			command:build()
		)
	end)

	it("builds command for dir", function()
		local command = command_builder:new({ junit_jar = "junit-jar-filepath" }, "maven")

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "dir")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")
		command:reports_dir("/reports/dir")

		assert.are.equal(
			([[javac 
      -d target/neotest-java/classes
      -cp $(cat target/neotest-java/classpath.txt)
      src/main/**/*.java 
      &&
      javac 
      -d target/neotest-java/classes
      -cp $(cat target/neotest-java/classpath.txt):target/neotest-java/classes 
      src/test/**/*.java
      && 
      java 
      -jar junit-jar-filepath 
      execute 
      -cp $(cat target/neotest-java/classpath.txt):target/neotest-java/classes
		  -p=com.example
      --fail-if-no-tests 
      --reports-dir=/reports/dir]]):gsub("\n", ""):gsub("%s+", " "),
			command:build()
		)
	end)

	it("builds command for file", function()
		local command = command_builder:new({ junit_jar = "junit-jar-filepath" }, "maven")

		command:ignore_wrapper(false)
		command:test_reference("com.example.ExampleTest", "shouldNotFail", "file")
		command:set_test_file("./src/test/java/com/example/ExampleApplicationTests.java")
		command:reports_dir("/reports/dir")

		assert.are.equal(
			([[javac 
      -d target/neotest-java/classes
      -cp $(cat target/neotest-java/classpath.txt)
      src/main/**/*.java 
      &&
      javac 
      -d target/neotest-java/classes
      -cp $(cat target/neotest-java/classpath.txt):target/neotest-java/classes 
      src/test/**/*.java
      && 
      java 
      -jar junit-jar-filepath 
      execute 
      -cp $(cat target/neotest-java/classpath.txt):target/neotest-java/classes
      -c=com.example.ExampleTest 
      --fail-if-no-tests 
      --reports-dir=/reports/dir]]):gsub("\n", ""):gsub("%s+", " "),
			command:build()
		)
	end)
end)
