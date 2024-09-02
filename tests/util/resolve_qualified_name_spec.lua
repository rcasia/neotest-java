---@diagnostic disable: undefined-field
local async = require("nio").tests
local resolve_qualified_name = require("neotest-java.util.resolve_qualified_name")

local cwd = vim.fn.getcwd()
local EXAMPLE_FILEPATH = cwd .. "/tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
local EXAMPLE_PACKAGE = "com.example.ExampleTest"
local BAD_EXAMPLE_FILEPATH = cwd .. "/tests/fixtures/maven-demo/src/test/java/com/example/NonExistentTest.java"

describe("resolve_qualified_name function", function()
	async.it("it should resolve package from filename", function()
		assert.are.equal(EXAMPLE_PACKAGE, resolve_qualified_name(EXAMPLE_FILEPATH))
	end)

	async.it("it should error when file does not exist", function()
		assert.has_error(function()
			resolve_qualified_name(BAD_EXAMPLE_FILEPATH)
		end, string.format("file does not exist: %s", BAD_EXAMPLE_FILEPATH))
	end)

	local function take_just_the_dependency(line)
		-- Manejar casos estándar, capturando 'groupId:artifactId' y la versión
		local group_and_artifact, version = line:match("([%w._-]+:[%w._-]+):[%w._-]*:([%w._%-]+)")
		if group_and_artifact and version then
			return group_and_artifact .. ":" .. version
		end

		return nil
	end

	async.it("", function()
		-- local result = take_just_the_dependency("+--- org.springframework.boot:spring-boot-starter:3.1.0")
		-- assert.are.same(result, "org.springframework.boot:spring-boot-starter:3.1.0")
		--
		-- local result2 = take_just_the_dependency("| +--- org.junit.platform:junit-platform-launcher:1.9.2 -> 1.9.3")
		-- assert.are.same(result2, "org.junit.platform:junit-platform-launcher:1.9.3")

		local result3 = take_just_the_dependency("javax.servlet:javax.servlet-api:jar:3.1.0:provided")
		assert.are.same("javax.servlet:javax.servlet-api:3.1.0", result3)

		local result3 = take_just_the_dependency("com.google.errorprone:error_prone_annotations:jar:2.28.0:compile")
		assert.are.same("com.google.errorprone:error_prone_annotations:2.28.0", result3)

		local result3 = take_just_the_dependency("org.hamcrest:hamcrest:jar:2.2:test")
		assert.are.same("org.hamcrest:hamcrest:2.2", result3)
	end)
end)
