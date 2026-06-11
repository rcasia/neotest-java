---@diagnostic disable: undefined-field
local xml_reader = require("neotest-java.util.xml_reader")
local async = require("tests.async_helpers").async
local eq = require("tests.assertions").eq

local SIMPLE_POM = [[<?xml version="1.0" encoding="UTF-8"?>
<project>
  <artifactId>my-app</artifactId>
  <build>
    <directory>target</directory>
  </build>
</project>
]]

local MALFORMED_XML = "<project><artifactId>my-app"

--- Build a stub `deps` table with optional overrides.
--- @param overrides table<string, any> | nil
--- @return table
local function stub_deps(overrides)
	local read_calls, parse_calls = {}, {}
	local function read_file(filepath)
		table.insert(read_calls, filepath)
		return SIMPLE_POM
	end
	local function xml_parse(content)
		table.insert(parse_calls, content)
		local root = { _attr = {}, project = { _attr = {} } }
		root.project.artifactId = "my-app"
		root.project.build = { _attr = {}, directory = "target" }
		return root
	end
	local deps = {
		read_file = read_file,
		xml_parse = xml_parse,
		_read_calls = read_calls,
		_parse_calls = parse_calls,
	}
	if overrides then
		for k, v in pairs(overrides) do
			deps[k] = v
		end
	end
	return deps
end

describe("XmlReader", function()
	describe("read_tag with stub dependencies", function()
		it("resolves a single-segment selector to a scalar value", function()
			-- given
			local deps = stub_deps()
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.read_tag("/fake/pom.xml", "project.artifactId")

			-- then
			eq({ value = "my-app", found = true, error = nil }, result)
		end)

		it("resolves a multi-segment selector to a scalar value", function()
			-- given
			local deps = stub_deps()
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.read_tag("/fake/pom.xml", "project.build.directory")

			-- then
			eq({ value = "target", found = true, error = nil }, result)
		end)

		it("returns found=false when a tag does not exist", function()
			-- given
			local deps = stub_deps()
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.read_tag("/fake/pom.xml", "project.missing.deeply")

			-- then
			eq({ value = nil, found = false, error = nil }, result)
		end)

		it("returns found=false when the selector resolves to a complex (table) node", function()
			-- given
			local deps = stub_deps()
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.read_tag("/fake/pom.xml", "project.build")

			-- then
			eq({ value = nil, found = false, error = nil }, result)
		end)

		it("surfaces file read errors instead of throwing", function()
			-- given
			local deps = stub_deps({
				read_file = function()
					error("disk on fire")
				end,
			})
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.read_tag("/fake/pom.xml", "project.artifactId")

			-- then
			eq(false, result.found)
			eq(nil, result.value)
			assert.is_not_nil(result.error)
			assert.is_truthy(result.error:find("disk on fire"))
		end)

		it("surfaces XML parse errors instead of throwing", function()
			-- given
			local deps = stub_deps({
				xml_parse = function()
					error("unexpected token at line 1")
				end,
			})
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.read_tag("/fake/pom.xml", "project.artifactId")

			-- then
			eq(false, result.found)
			eq(nil, result.value)
			assert.is_not_nil(result.error)
			assert.is_truthy(result.error:find("unexpected token"))
		end)

		it("uses injected stubs and never touches the real neotest.lib.file or neotest.lib.xml", function()
			-- given
			local reader = xml_reader.new({
				read_file = function()
					return SIMPLE_POM
				end,
				xml_parse = function()
					return { _attr = {}, project = { _attr = {}, artifactId = "stubbed" } }
				end,
			})

			-- when
			local result = reader.read_tag("/fake/pom.xml", "project.artifactId")

			-- then — the result was produced entirely from the stubs
			eq({ value = "stubbed", found = true, error = nil }, result)
		end)
	end)

	describe("parse with stub dependencies", function()
		it("returns the full parsed tree on success", function()
			-- given
			local deps = stub_deps()
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.parse("/fake/pom.xml")

			-- then
			eq(nil, result.error)
			eq("my-app", result.tree.project.artifactId)
			eq("target", result.tree.project.build.directory)
		end)

		it("surfaces file read errors", function()
			-- given
			local deps = stub_deps({
				read_file = function()
					error("cannot stat file")
				end,
			})
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.parse("/fake/pom.xml")

			-- then
			eq(nil, result.tree)
			assert.is_not_nil(result.error)
			assert.is_truthy(result.error:find("cannot stat file"))
		end)

		it("surfaces XML parse errors", function()
			-- given
			local deps = stub_deps({
				xml_parse = function()
					error("malformed XML")
				end,
			})
			local reader = xml_reader.new({ read_file = deps.read_file, xml_parse = deps.xml_parse })

			-- when
			local result = reader.parse("/fake/pom.xml")

			-- then
			eq(nil, result.tree)
			assert.is_not_nil(result.error)
			assert.is_truthy(result.error:find("malformed XML"))
		end)
	end)

	describe("read_tag with default (real) dependencies", function()
		it("reads and parses a real XML file from disk", function()
			async(function()
				-- given
				local tmp_path = vim.fn.tempname()
				local f = assert(io.open(tmp_path, "w"))
				f:write([[<root><greeting>hello</greeting></root>]])
				f:close()

				-- when
				local reader = xml_reader.new() -- no deps → real libraries
				local result = reader.read_tag(tmp_path, "root.greeting")

				-- then
				os.remove(tmp_path)
				eq({ value = "hello", found = true, error = nil }, result)
			end)()
		end)
	end)

	describe("default module export", function()
		it("returns the scalar value when a tag resolves", function()
			async(function()
				-- given
				local tmp_path = vim.fn.tempname()
				local f = assert(io.open(tmp_path, "w"))
				f:write([[<root><build><dir>out</dir></build></root>]])
				f:close()

				-- when
				local value = xml_reader.read_tag(tmp_path, "root.build.dir")

				-- then
				os.remove(tmp_path)
				eq("out", value)
			end)()
		end)

		it("returns nil when a tag is missing", function()
			async(function()
				-- given
				local tmp_path = vim.fn.tempname()
				local f = assert(io.open(tmp_path, "w"))
				f:write([[<root><other>value</other></root>]])
				f:close()

				-- when
				local value = xml_reader.read_tag(tmp_path, "root.missing")

				-- then
				os.remove(tmp_path)
				eq(nil, value)
			end)()
		end)

		it("returns nil for malformed XML rather than throwing", function()
			async(function()
				-- given
				local tmp_path = vim.fn.tempname()
				local f = assert(io.open(tmp_path, "w"))
				f:write(MALFORMED_XML)
				f:close()

				-- when / then — must not throw
				local ok, value = pcall(xml_reader.read_tag, tmp_path, "project.artifactId")

				-- then
				os.remove(tmp_path)
				eq(true, ok)
				eq(nil, value)
			end)()
		end)
	end)
end)
