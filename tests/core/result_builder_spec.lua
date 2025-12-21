local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests
local async = require("nio").tests
local plugin = require("neotest-java")
local result_builder = require("neotest-java.core.result_builder")
local tempname_fn = require("nio").fn.tempname
local Path = require("neotest-java.util.path")

local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")

local TEMPDIR = os.getenv("TEMP") or os.getenv("TMP") or vim.uv.os_tmpdir()
local TEMPNAME = TEMPDIR .. "/neotest-java-result-builder-test.txt"
local MAVEN_REPORTS_DIR = Path(vim.loop.cwd()).append("/tests/fixtures/maven-demo/target/surefire-reports/")

local SUCCESSFUL_RESULT = {
	code = 0,
	output = "output",
}

local DEFAULT_SPEC = {
	cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
	context = {
		reports_dir = MAVEN_REPORTS_DIR,
	},
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
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return {}
		end

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local _, err = pcall(result_builder.build_results, DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir)

		-- then
		assert.match("no report file could be generated", err)
	end)

	async.it("ignores report file when cannot be read", function()
		--given
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return { "TEST-someTest.xml" }
		end
		local read_file = function()
			error("cannot read file")
		end

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		local expected = {
			["com.example.ExampleTest#shouldFail"] = {
				status = "skipped",
				output = TEMPNAME,
			},
			["com.example.ExampleTest#shouldNotFail"] = {
				status = "skipped",
				output = TEMPNAME,
			},
		}
		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

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

		local report_file = [[
				<testsuite>
					<testcase name="shouldFail" classname="com.example.ExampleTest" time="0.001">
						<failure message="expected: &lt;true&gt; but was: &lt;false&gt;" type="org.opentest4j.AssertionFailedError">
							OUTPUT TEXT
						</failure>
					</testcase>
					<testcase name="shouldNotFail" classname="com.example.ExampleTest" time="0"/>
				</testsuite>
		]]

		local file_path = create_tempfile_with_test(file_content)
		local tree = plugin.discover_positions(file_path)
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ExampleTest#shouldFail"] = {
				-- errors = { { line = 13, message = "expected: <true> but was: <false>" } },
				errors = { { message = "expected: <true> but was: <false>" } },
				short = "expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			["com.example.ExampleTest#shouldNotFail"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
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
		local report_file = [[
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

		local file_path = create_tempfile_with_test(file_content)
		local tree = plugin.discover_positions(file_path)
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ErroneousTest#shouldFailOnError"] = {
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

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		assert.are.same(expected, results)
	end)

	async.it("builds the results for integrations tests", function()
		--given
		local file_content = [[

			package com.example.demo;

			import org.junit.jupiter.api.Test;
			import org.springframework.boot.test.context.SpringBootTest;

			@SpringBootTest
			class RepositoryIT {

				@Test
				void shouldWorkProperly() {
				}

			}

		]]

		local report_file = [[
				<testsuite>
					<testcase name="shouldWorkProperly" classname="com.example.demo.RepositoryIT" time="0.439">
						<system-out>
							SYSTEM OUTPUT TEXT
						</system-out>
					</testcase>
				</testsuite>
			]]

		local file_path = create_tempfile_with_test(file_content)
		local expected = {
			["com.example.demo.RepositoryIT#shouldWorkProperly"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		local tree = plugin.discover_positions(file_path)
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		assert.are.same(expected, results)
	end)

	async.it("builds results for parameterized test with @CsvSource", function()
		--given
		local file_content = [[
			package com.example;

			import org.junit.jupiter.params.ParameterizedTest;
			import org.junit.jupiter.params.provider.CsvSource;

			import static org.junit.jupiter.api.Assertions.assertTrue;

			public class ParameterizedMethodTest {

					@ParameterizedTest
					@CsvSource({
									"1,1,2",
									"1,2,3",
									"2,3,5",
									"15,15,30"
					})
					void parameterizedMethodShouldNotFail(Integer a, Integer b, Integer result) {
							assertTrue(a + b == result);
					}

					@ParameterizedTest
					@CsvSource({
									"1,2",
									"3,4",
									"4,4"
					})
					void parameterizedMethodShouldFail(Integer a, Integer b) {
							assertTrue(a == b);
					}
			}

		]]

		local report_file = [[
				<testsuite>
					<testcase name="parameterizedMethodShouldFail(Integer, Integer)[1]" classname="com.example.ParameterizedMethodTest" time="0.001">
						<failure message="expected: &lt;true&gt; but was: &lt;false&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
					</testcase>
					<testcase name="parameterizedMethodShouldFail(Integer, Integer)[2]" classname="com.example.ParameterizedMethodTest" time="0.001">
						<failure message="expected: &lt;true&gt; but was: &lt;false&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
					</testcase>
					<testcase name="parameterizedMethodShouldFail(Integer, Integer)[3]" classname="com.example.ParameterizedMethodTest" time="0.001"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[1]" classname="com.example.ParameterizedMethodTest" time="0.001"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[2]" classname="com.example.ParameterizedMethodTest" time="0"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[3]" classname="com.example.ParameterizedMethodTest" time="0"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[4]" classname="com.example.ParameterizedMethodTest" time="0"/>
				</testsuite>
			]]

		local file_path = create_tempfile_with_test(file_content)

		local tree = plugin.discover_positions(file_path)
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ParameterizedMethodTest#parameterizedMethodShouldFail(java.lang.Integer, java.lang.Integer)"] = {
				errors = {
					{
						-- line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>",
					},
					{
						-- line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
					},
				},
				short = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>\nparameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			["com.example.ParameterizedMethodTest#parameterizedMethodShouldNotFail(java.lang.Integer, java.lang.Integer, java.lang.Integer)"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}
		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		assert.are.same(expected, results)
	end)

	async.it("builds the results for parameterized with @EmptySource test", function()
		--given
		local file_content = [[
			package com.example;

			import org.junit.jupiter.params.ParameterizedTest;
			import org.junit.jupiter.params.provider.EmptySource;

			import static org.junit.jupiter.api.Assertions.assertTrue;

			import org.apache.logging.log4j.util.Strings;

			import static org.junit.jupiter.api.Assertions.assertFalse;

			public class EmptySourceTest {

					@ParameterizedTest
					@EmptySource
					void emptySourceShouldPass(String input) {
							assertTrue(Strings.isBlank(input));
					}

					@ParameterizedTest
					@EmptySource
					void emptySourceShouldFail(String input) {
							assertFalse(Strings.isBlank(input));
					}
			}
		]]

		local report_file = [[
				<testsuite>
					<testcase name="emptySourceShouldFail(String)[1]" classname="com.example.EmptySourceTest" time="0.003">
						<failure message="expected: &lt;false&gt; but was: &lt;true&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
					</testcase>
					<testcase name="emptySourceShouldPass(String)[1]" classname="com.example.EmptySourceTest" time="0.001"/>
				</testsuite>
			]]

		local file_path = create_tempfile_with_test(file_content)

		local tree = plugin.discover_positions(file_path)
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.EmptySourceTest#emptySourceShouldFail(java.lang.String)"] = {
				errors = {
					{
						-- line = 22,
						message = "emptySourceShouldFail(String)[1] -> expected: <false> but was: <true>",
					},
				},
				short = "emptySourceShouldFail(String)[1] -> expected: <false> but was: <true>",
				status = "failed",
				output = TEMPNAME,
			},
			["com.example.EmptySourceTest#emptySourceShouldPass(java.lang.String)"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}
		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		print(vim.inspect({ results = results, expected = expected }))
		assert.are.same(expected, results)
	end)

	async.it("should build results for nested tests", function()
		local file_content = [[
			package com.example;

			import org.junit.jupiter.api.Nested;
			import org.junit.jupiter.api.Test;

			class NestedTest {

				@Test
				void plainTest() {

				}

				@Nested
				class Level2 {

					@Test
					void nestedTest() {

					}
				}

			}
		]]

		local report_file = [[
				<testsuite>
					<testcase name="plainTest()" classname="com.example.NestedTest" time="0.004">
						<system-out></system-out>
					</testcase>
					<testcase name="nestedTest()" classname="com.example.NestedTest$Level2" time="0">
						<system-out></system-out>
					</testcase>
				</testsuite>
			]]

		local file_path = create_tempfile_with_test(file_content)

		local tree = plugin.discover_positions(file_path)
		local scan_dir = function(dir)
			if dir ~= DEFAULT_SPEC.context.reports_dir.to_string() then
				error("should scan in spec.context.reports_dir")
			end
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.NestedTest$Level2#nestedTest"] = {
				status = "passed",
				output = TEMPNAME,
			},
			["com.example.NestedTest#plainTest"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		assert.are.same(expected, results)
	end)
end)
