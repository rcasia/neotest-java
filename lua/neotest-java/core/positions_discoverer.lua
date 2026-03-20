local lib = require("neotest.lib")
local resolve_package_name = require("neotest-java.util.resolve_package_name")
local Path = require("neotest-java.model.path")
local namespace_id = require("neotest-java.core.position_ids.namespace_id")
local nio = require("nio")
local test_method_id = require("neotest-java.core.position_ids.test_method_id")
local Tree = require("neotest.types.tree")

--- @class neotest-java.PositionsDiscoverer
--- @field discover_positions fun(file_path: string): neotest.Tree?

--- @class neotest-java.PositionsDiscoverer.Dependencies
--- @field method_id_resolver neotest-java.MethodIdResolver

--- Check if a file is a Groovy file
---@param file_path string
---@return boolean
local function is_groovy_file(file_path)
	return file_path:match("%.groovy$") ~= nil
end

--- Check if Groovy treesitter parser is available
---@return boolean
local function has_groovy_parser()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return false
	end
	return parsers.has_parser("groovy")
end

--- Get file line count
---@param file_path string
---@return number
local function get_line_count(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return 1
	end
	local count = 0
	for _ in file:lines() do
		count = count + 1
	end
	file:close()
	return math.max(count, 1)
end

--- Groovy/Spock treesitter query for test discovery
--- Matches:
--- - Class declarations (namespace)
--- - Methods with string names: def "test description"()
--- - Methods annotated with @Test
local groovy_query = [[
  ;; Test class
  (class_declaration
    name: (identifier) @namespace.name
  ) @namespace.definition

  ;; Spock test methods with string names: def "test name"()
  (method_declaration
    name: (string_literal) @test.name
  ) @test.definition

  ;; @Test annotated methods
  (method_declaration
    (modifiers
      (marker_annotation
        name: (identifier) @annotation
        (#eq? @annotation "Test")
      )
    )
    name: (identifier) @test.name
  ) @test.definition
]]

--- Parse Groovy/Spock test file using regex (fallback)
---@param file_path string
---@param deps neotest-java.PositionsDiscoverer.Dependencies
---@return neotest.Tree | nil
local function parse_groovy_file_regex(file_path, deps)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	-- Extract package name
	local package_name = content:match("package%s+([%w%.]+)") or ""

	-- Extract class name
	local class_name = content:match("class%s+(%w+)")
	if not class_name then
		return nil
	end

	-- Extract Spock test methods
	local method_names = {}

	-- Pattern for Spock-style: def "test description"()
	for method_name in content:gmatch('def%s+"([^"]+)"%s*%([^)]*%)') do
		table.insert(method_names, method_name)
	end

	-- Pattern for @Test annotated methods in Groovy
	for method_name in content:gmatch("@Test%s+def%s+(%w+)%s*%b()") do
		if not vim.tbl_contains(method_names, method_name) then
			table.insert(method_names, method_name)
		end
	end

	-- Build full class name
	local full_class_name = package_name ~= "" and (package_name .. "." .. class_name) or class_name

	-- Get file line count for ranges
	local line_count = get_line_count(file_path)

	-- Build tree structure
	local file_pos = {
		type = "file",
		path = file_path,
		name = Path(file_path):name(),
		id = file_path,
		range = { 0, 0, line_count, 0 },
	}

	local test_positions = {}
	for _, method_name in ipairs(method_names) do
		table.insert(test_positions, {
			{
				type = "test",
				name = method_name,
				id = full_class_name .. "#" .. method_name .. "()",
				path = file_path,
				range = { 0, 0, 0, 0 },
			},
		})
	end

	local namespace_pos = {
		type = "namespace",
		name = class_name,
		id = full_class_name,
		path = file_path,
		range = { 0, 0, line_count, 0 },
	}

	local tree_list = { file_pos, { namespace_pos } }
	for _, test in ipairs(test_positions) do
		table.insert(tree_list[2], test)
	end

	local tree = Tree.from_list(tree_list, function(pos)
		return pos.id
	end)

	-- Set up ref functions
	if tree then
		for _, key in ipairs(tree._children) do
			local child = tree:get_key(key)
			if child then
				for _, test_key in ipairs(child._children or {}) do
					local test_node = child:get_key(test_key)
					if test_node and test_node:data().type == "test" then
						vim.schedule(function()
							local id
							test_node:data().ref = function()
								if not id then
									if vim.in_fast_event() then
										nio.scheduler()
									end
									id = nio.run(function()
										return deps.method_id_resolver.resolve_complete_method_id(
											full_class_name,
											test_node:data().name,
											Path(file_path):parent()
										)
									end):wait()
								end
								return full_class_name .. "#" .. id
							end
						end)
					end
				end
			end
		end
	end

	return tree
end

--- Parse Groovy/Spock test file using treesitter (with regex fallback)
---@param file_path string
---@param deps neotest-java.PositionsDiscoverer.Dependencies
---@return neotest.Tree | nil
local function parse_groovy_file(file_path, deps)
	-- Try treesitter first if groovy parser is available
	if has_groovy_parser() then
		local tree = lib.treesitter.parse_positions(file_path, groovy_query, {
			require_namespaces = true,
			nested_tests = false,
			position_id = function(position, parents)
				if position.type == "file" or position.type == "dir" then
					return position.path
				end

				-- For Groovy, extract package from file content
				local file = io.open(file_path, "r")
				local package_name = ""
				if file then
					local content = file:read("*a")
					file:close()
					package_name = content:match("package%s+([%w%.]+)") or ""
				end

				if position.type == "namespace" then
					local full_name = package_name ~= "" and (package_name .. "." .. position.name) or position.name
					return full_name
				end

				-- For test methods, build the full ID
				local namespace_node = parents[#parents]
				local class_name = namespace_node and namespace_node.name or ""
				local full_class_name = package_name ~= "" and (package_name .. "." .. class_name) or class_name
				return full_class_name .. "#" .. position.name .. "()"
			end,
		})

		-- Set up ref functions for test methods
		if tree then
			vim.iter(tree:iter())
				:map(function(_, node)
					return node
				end)
				:each(function(node)
					vim.schedule(function()
						local id
						tree:get_key(node.id):data().ref = function()
							if node.type ~= "test" then
								return node.id
							end
							local parent_id = tree:get_key(node.id):parent():data().id

							if not id then
								if vim.in_fast_event() then
									nio.scheduler()
								end

								id = nio.run(function()
									return deps.method_id_resolver.resolve_complete_method_id(
										parent_id,
										node.name,
										Path(node.path):parent()
									)
								end):wait()
							end
							return parent_id .. "#" .. id
						end
					end)
				end)
		end

		return tree
	end

	-- Fallback to regex-based parsing
	return parse_groovy_file_regex(file_path, deps)
end

--- @param deps neotest-java.PositionsDiscoverer.Dependencies
--- @return neotest-java.PositionsDiscoverer
local PositionsDiscoverer = function(deps)
	local annotations = { "Test", "ParameterizedTest", "TestFactory", "CartesianTest" }
	local a = vim.iter(annotations)
		:map(function(v)
			return string.format([["%s"]], v)
		end)
		:join(" ")

	local java_query = [[

    ;; Test class
    (class_declaration
      name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Annotated test methods
    (method_declaration
      (modifiers
        [
          (marker_annotation
            name: (identifier) @annotation
            (#any-of? @annotation ]] .. a .. [[)
          )
          (annotation
            name: (identifier) @annotation
            (#any-of? @annotation ]] .. a .. [[)
          )
        ]
      )
      name: (identifier) @test.name
    ) @test.definition

  ]]

	--- @type neotest-java.PositionsDiscoverer
	return {

		---Given a file path, parse all the tests within it.
		---@async
		---@param file_path string Absolute file path
		---@return neotest.Tree | nil
		discover_positions = function(file_path)
			-- Use Groovy-specific parsing for Groovy files
			if is_groovy_file(file_path) then
				return parse_groovy_file(file_path, deps)
			end

			-- Use treesitter for Java files
			local tree = lib.treesitter.parse_positions(file_path, java_query, {
				require_namespaces = true,
				nested_tests = false,
				position_id = function(position, parents)
					if position.type == "file" or position.type == "dir" then
						return position.path
					end

					local package_name = resolve_package_name(Path(position.path))

					if position.type == "namespace" then
						return namespace_id(position, parents, package_name)
					end

					return test_method_id(position, parents, package_name)
				end,
			})

			vim
				.iter(tree:iter())
				:map(function(_, node)
					return node
				end)
				--- @param node neotest.Position
				:each(function(node)
					vim.schedule(function()
						local id
						tree:get_key(node.id):data().ref = function()
							if node.type ~= "test" then
								return node.id
							end
							local parent_id = tree:get_key(node.id):parent():data().id

							if not id then
								if vim.in_fast_event() then
									nio.scheduler()
								end

								id = nio.run(function()
									return deps.method_id_resolver.resolve_complete_method_id(
										parent_id,
										node.name,
										Path(node.path):parent()
									)
								end):wait()
							end
							return parent_id .. "#" .. id
						end
					end)
				end)

			return tree
		end,
	}
end

return PositionsDiscoverer
