local assertions = require("tests.assertions")
local eq = assertions.eq

local Path = require("neotest-java.model.path")

local MethodIdResolver = require("neotest-java.method_id_resolver")

describe("Method Id Resolver", function()
	--- @type neotest-java.ClasspathProvider
	local fake_classpath_provider = {
		get_classpath = function(base_dir)
			eq(Path("my_module_dir"), base_dir, "base_dir should be passed correctly")
			return "my_classpath"
		end,
	}
	local fake_command_executor_invocations

	--- @return neotest-java.CommandExecutor
	local fake_command_executor = function(expected_result)
		return {
			execute_command = function(command, args)
				fake_command_executor_invocations[#fake_command_executor_invocations + 1] =
					{ command = command, args = args }

				return expected_result
			end,
		}
	end
	--- @type neotest-java.LspBinaries
	local fake_binaries = {
		javap = function(cwd)
			return Path("/fake/javap")
		end,

		java = function(cwd)
			return Path("/fake/java")
		end,
	}

	before_each(function()
		fake_command_executor_invocations = {}
	end)

	it("runs javap command correctly", function()
		local resolver = MethodIdResolver({ --
			binaries = fake_binaries,
			classpath_provider = fake_classpath_provider,
			command_executor = fake_command_executor({
				stdout = [[
    Compiled from "Something1Test.java"
    public class com.example.application.Something1Test {
        public com.example.application.Something1Test();
        void testSomething();
        void testSomething1();
        void someMonths_scv(int, java.lang.String, java.lang.Integer, com.example.application.model.TestArgs$Role);
        void someMonths_enum(com.example.application.Something1Test$TestMonth);
        void testPersonFromCsv(com.example.model.Person);
        void testPersonAge(com.example.model.Person);
        static java.util.stream.Stream<com.example.model.Person> personProvider();
    }
				]],
				stderr = "",
				exit_code = 0,
			}),
		})

		resolver.resolve_complete_method_id("com.example.ExampleTest", "someMonths_scv")

		eq(1, #fake_command_executor_invocations, "command_executor should be invoked once")
		eq({
			command = "bash",
			args = { "-c", Path("/fake/javap"):to_string(), "-cp=my_classpath", "com.example.ExampleTest" },
		}, fake_command_executor_invocations[1])
	end)

	it("resolves the complete method ids", function()
		local resolver = MethodIdResolver({ --
			binaries = fake_binaries,
			classpath_provider = fake_classpath_provider,
			command_executor = fake_command_executor({
				stdout = [[
    Compiled from "Something1Test.java"
    public class com.example.application.Something1Test {
        public com.example.application.Something1Test();
        void testSomething();
        void testSomething1();
        void someMonths_scv(int, java.lang.String, java.lang.Integer, com.example.application.model.TestArgs$Role);
        void someMonths_enum(com.example.application.Something1Test$TestMonth);
        void testPersonFromCsv(com.example.model.Person);
        void testPersonAge(com.example.model.Person);
        static java.util.stream.Stream<com.example.model.Person> personProvider();
    }
				]],
				stderr = "",
				exit_code = 0,
			}),
		})

		eq(
			"someMonths_scv(int, java.lang.String, java.lang.Integer, com.example.application.model.TestArgs$Role)",
			resolver.resolve_complete_method_id("com.example.ExampleTest", "someMonths_scv")
		)
		eq("testSomething()", resolver.resolve_complete_method_id("com.example.ExampleTest", "testSomething"))
		eq("testSomething1()", resolver.resolve_complete_method_id("com.example.ExampleTest", "testSomething1"))
		eq(
			"testPersonAge(com.example.model.Person)",
			resolver.resolve_complete_method_id("com.example.ExampleTest", "testPersonAge")
		)
		eq("personProvider()", resolver.resolve_complete_method_id("com.example.ExampleTest", "personProvider"))
	end)
end)
