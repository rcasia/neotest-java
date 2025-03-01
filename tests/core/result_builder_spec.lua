local async = require("nio").tests
local plugin = require("neotest-java")
local result_builder = require("neotest-java.core.result_builder")
local tempname_fn = require("nio").fn.tempname

local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
local TEMPNAME = "/tmp/tempname-1234"
local MAVEN_REPORTS_DIR = vim.loop.cwd() .. "/tests/fixtures/maven-demo/target/surefire-reports/"

local SUCCESSFUL_RESULT = {
	code = 0,
	output = "output",
}

local tempfiles = {}

---@param content string
---@return string filepath
local function create_tempfile_with_test(content)
	local path = vim.fn.tempname() .. ".java"
	table.insert(tempfiles, path)
	local file = io.open(path, "w")
	file:write(content)
	file:close()
	return path
end

describe("ResultBuilder", function()
	async.before_each(function()
		-- mock the tempname function to return a fixed value
		require("nio").fn.tempname = function()
			return TEMPNAME
		end
	end)

	async.after_each(function()
		require("nio").fn.tempname = tempname_fn

		-- remove all temp files
		for _, path in ipairs(tempfiles) do
			os.remove(path)
		end
	end)

	async.it("throws error when no report files found", function()
		--given
		local scan_dir = function()
			return {}
		end

		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local _, err = pcall(result_builder.build_results, runSpec, SUCCESSFUL_RESULT, tree, scan_dir)

		-- then
		assert.match("no report file could be generated", err)
	end)

	async.it("ignores report file when cannot be read", function()
		--given
		local scan_dir = function()
			return { "TEST-someTest.xml" }
		end
		local read_file = function()
			error("cannot read file")
		end

		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldFail"] = {
				status = "skipped",
				output = TEMPNAME,
			},
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldNotFail"] = {
				status = "skipped",
				output = TEMPNAME,
			},
		}
		--when
		local results = result_builder.build_results(runSpec, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		-- then
		assert.are.same(expected, results)
	end)

	async.it("should build results from report", function()
		--given
		local file_content = [[
			package com.example;
			import org.junit.jupiter.api.Test;

			import static org.junit.jupiter.api.Assertions.assertTrue;

			public class ExampleTest {
					@Test
					void shouldNotFail() {
							assertTrue(true);
					}

					@Test
					void shouldFail() {
							assertTrue(false);
					}
			}
		]]
		local file_path = create_tempfile_with_test(file_content)
		local tree = plugin.discover_positions(file_path)
		local scan_dir = function()
			return { file_path }
		end
		local read_file = function()
			return [[
				<testsuite>
					<testcase name="shouldFail" classname="com.example.ExampleTest" time="0.001">
						<failure message="expected: &lt;true&gt; but was: &lt;false&gt;" type="org.opentest4j.AssertionFailedError">
							OUTPUT TEXT
						</failure>
					</testcase>
					<testcase name="shouldNotFail" classname="com.example.ExampleTest" time="0"/>
				</testsuite>
			]]
		end
		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		--when
		local results = result_builder.build_results(runSpec, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		local expected = {
			[file_path .. "::ExampleTest::shouldFail"] = {
				-- errors = { { line = 13, message = "expected: <true> but was: <false>" } },
				errors = { { message = "expected: <true> but was: <false>" } },
				short = "expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			[file_path .. "::ExampleTest::shouldNotFail"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for a test that has an error at start", function()
		--given
		local file_content = [[

			package com.example;

			import static org.junit.jupiter.api.Assertions.assertEquals;

			import org.junit.jupiter.api.Test;
			import org.springframework.beans.factory.annotation.Value;
			import org.springframework.boot.test.context.SpringBootTest;

			import com.example.demo.DemoApplication;

			@SpringBootTest(classes = { DemoApplication.class })
			public class ErroneousTest {
					@Value("${foo.property}") String requiredProperty;

					@Test
					void shouldFailOnError(){
						assertEquals("test", requiredProperty);
					}
			}

		]]
		local file_path = create_tempfile_with_test(file_content)
		local tree = plugin.discover_positions(file_path)
		local scan_dir = function()
			return { file_path }
		end
		local read_file = function()
			return [[
				<testsuite>
					<testcase name="shouldFailOnError" classname="com.example.ErroneousTest" time="0.001">
						<error message="Error creating bean with name &apos;com.example.ErroneousTest&apos;: Injection of autowired dependencies failed" type="org.springframework.beans.factory.BeanCreationException">
							ERROR OUTPUT TEXT
						</error>
						<system-out>
							SYSTEM OUTPUT TEXT
						</system-out>
					</testcase>
				</testsuite>
			]]
		end
		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		--when
		local results = result_builder.build_results(runSpec, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		local expected = {
			[file_path .. "::ErroneousTest::shouldFailOnError"] = {
				errors = {
					{
						message = "Error creating bean with name 'com.example.ErroneousTest': Injection of autowired dependencies failed",
					},
				},
				output = TEMPNAME,
				short = "Error creating bean with name 'com.example.ErroneousTest': Injection of autowired dependencies failed",
				status = "failed",
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for integrations tests", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

		--then
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java::RepositoryIT::shouldWorkProperly"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for parameterized test with @CsvSource for maven", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir
			.. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

		--then
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::ParameterizedMethodTest::parameterizedMethodShouldFail"] = {
				errors = {
					-- {
					-- 	line = 27,
					-- 	message = "expected: <true> but was: <false>",
					-- },
					-- {
					-- 	line = 27,
					-- 	message = "expected: <true> but was: <false>",
					-- },
					{
						line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>",
					},
					{
						line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
					},
				},
				short = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>\nparameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::ParameterizedMethodTest::parameterizedMethodShouldNotFail"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for parameterized with @EmptySource test", function()
		--given
		local project_dir = "gradle-groovy-demo"
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/" .. project_dir,
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir
			.. "tests/fixtures/"
			.. project_dir
			.. "/src/test/java/com/example/EmptySourceTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

		--then
		local expected = {
			[current_dir .. "tests/fixtures/" .. project_dir .. "/src/test/java/com/example/EmptySourceTest.java::EmptySourceTest::emptySourceShouldFail"] = {
				errors = {
					{
						line = 22,
						message = "emptySourceShouldFail(String)[1] -> expected: <false> but was: <true>",
					},
				},
				short = "emptySourceShouldFail(String)[1] -> expected: <false> but was: <true>",
				status = "failed",
				output = TEMPNAME,
			},
			[current_dir .. "tests/fixtures/" .. project_dir .. "/src/test/java/com/example/EmptySourceTest.java::EmptySourceTest::emptySourceShouldPass"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)
end)
