local read_file = require("neotest-java.util.read_file")
local TEST_CLASS_PATTERNS = require("neotest-java.types.test_class_patterns")

local function resolve_qualified_name(filename)
	---@param raw_query string
	---@param content string
	---@return string[]
	local function find_in_text(raw_query, content)
		local query = vim.treesitter.query.parse("java", raw_query)

		local lang_tree = vim.treesitter.get_string_parser(content, "java")
		local root = lang_tree:parse()[1]:root()

		local result = {}
		for _, node, _ in query:iter_captures(root, content, 0, -1) do --luacheck: ignore 512 loop is executed at most once
			result[#result + 1] = vim.treesitter.get_node_text(node, content)
		end
		return result
	end

	-- read the file
	local ok, content = pcall(function()
		return read_file(filename)
	end)
	if not ok then
		error(string.format("file does not exist: %s", filename))
	end

	-- get the package name
	local package_query = [[

      ((package_declaration (scoped_identifier) @package.name))

      ((package_declaration (identifier) @package.name))

  ]]

	local class_name_query = [[
    ((class_declaration (identifier) @target))
  ]]

	local package_lines = find_in_text(package_query, content)

	local package_line = (package_lines and package_lines[1]) and (package_lines[1] .. ".") or ""
	local names = find_in_text(class_name_query, content)

	-- as there can be different class names
	-- searches for the one the mathces the test class patterns
	local name = ""
	for _, _name in ipairs(names) do
		for _, pattern in ipairs(TEST_CLASS_PATTERNS) do
			if _name:find(pattern) then
				name = _name
				break
			end
		end
	end

	return package_line .. name
end

return resolve_qualified_name
