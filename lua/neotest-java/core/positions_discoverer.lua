local lib = require("neotest.lib")
local resolve_package_name = require("neotest-java.util.resolve_package_name")
local Path = require("neotest-java.model.path")
local namespace_id = require("neotest-java.core.position_ids.namespace_id")
local nio = require("nio")
local test_method_id = require("neotest-java.core.position_ids.test_method_id")

local function as_capture_node(capture)
	if type(capture) == "userdata" then
		return capture
	end

	if type(capture) == "table" then
		return capture[1]
	end

	return nil
end

local function get_match_type(captured_nodes)
	if captured_nodes["test.name"] then
		return "test"
	end

	if captured_nodes["namespace.name"] then
		return "namespace"
	end

	return nil
end

--- @param file_path string
--- @param source string
--- @param captured_nodes table<string, userdata | userdata[]>
--- @return neotest.Position | nil
local function build_position(file_path, source, captured_nodes)
	local match_type = get_match_type(captured_nodes)
	if not match_type then
		return nil
	end

	local name_node = as_capture_node(captured_nodes[match_type .. ".name"])
	local definition_node = as_capture_node(captured_nodes[match_type .. ".definition"])
	if not name_node or not definition_node then
		return nil
	end

	local name = vim.treesitter.get_node_text(name_node, source)

	if name_node:type() == "string" or name_node:type() == "string_literal" then
		name = name:gsub("^[\"']", ""):gsub("[\"']$", "")
	end

	return {
		type = match_type,
		path = file_path,
		name = name,
		range = { definition_node:range() },
	}
end

--- @param position neotest.Position
--- @param parents neotest.Position[]
--- @return string
local function position_id(position, parents)
	if position.type == "file" or position.type == "dir" then
		return position.path
	end

	local package_name = resolve_package_name(Path(position.path))

	if position.type == "namespace" then
		return namespace_id(position, parents, package_name)
	end

	return test_method_id(position, parents, package_name)
end

--- @class neotest-java.PositionsDiscoverer
--- @field discover_positions fun(file_path: string): neotest.Tree?

--- @class neotest-java.PositionsDiscoverer.Dependencies
--- @field method_id_resolver neotest-java.MethodIdResolver

local PositionsDiscoverer = {}

local function get_java_query()
	local annotations = { "Test", "ParameterizedTest", "TestFactory", "CartesianTest" }
	local a = vim.iter(annotations)
		:map(function(v)
			return string.format([["%s"]], v)
		end)
		:join(" ")

	return [[

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
end

local function get_groovy_query()
	local annotations = { "Test", "ParameterizedTest", "TestFactory", "CartesianTest" }
	local a = vim.iter(annotations)
		:map(function(v)
			return string.format([["%s"]], v)
		end)
		:join(" ")

	return [[

    ;; Test class (Spock specs extend Specification)
    (class_declaration
      name: (identifier) @namespace.name
    ) @namespace.definition

    ;; JUnit-style annotated methods in Groovy
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
      name: [
        (identifier) @test.name
        (string) @test.name
      ]
    ) @test.definition

    ;; Spock feature methods: def "test name"()
    ;; String literal method names are unique to Spock-style tests
    (method_declaration
      name: (string) @test.name
    ) @test.definition

  ]]
end

--- @param deps neotest-java.PositionsDiscoverer.Dependencies
--- @return neotest-java.PositionsDiscoverer
local function create_positions_discoverer(deps)
	--- @type neotest-java.PositionsDiscoverer
	return {

		---Given a file path, parse all the tests within it.
		---@async
		---@param file_path string Absolute file path
		---@return neotest.Tree | nil
		discover_positions = function(file_path)
			local is_groovy = file_path:match("%.groovy$")
			local query = is_groovy and get_groovy_query() or get_java_query()

			local tree = lib.treesitter.parse_positions(file_path, query, {
				require_namespaces = true,
				nested_tests = false,
				build_position = "require('neotest-java.core.positions_discoverer').build_position",
				position_id = "require('neotest-java.core.positions_discoverer').position_id",
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

PositionsDiscoverer.build_position = build_position
PositionsDiscoverer.position_id = position_id

setmetatable(PositionsDiscoverer, {
	__call = function(_, deps)
		return create_positions_discoverer(deps)
	end,
})

return PositionsDiscoverer
