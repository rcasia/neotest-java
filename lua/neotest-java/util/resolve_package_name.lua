local read_file = require("neotest-java.util.read_file")

local PACKAGE_QUERY = [[
  ((package_declaration (scoped_identifier) @package.name))
  ((package_declaration (identifier) @package.name))
]]

---Resolve the Java package name from a file.
---Returns "" if no package declaration is present.
---@param filename string
---@return string
local function resolve_package_name(filename)
	local function find_in_text(raw_query, content)
		local query = vim.treesitter.query.parse("java", raw_query)
		local lang_tree = vim.treesitter.get_string_parser(content, "java")
		local root = lang_tree:parse()[1]:root()

		local result = {}
		for _, node in query:iter_captures(root, content, 0, -1) do
			result[#result + 1] = vim.treesitter.get_node_text(node, content)
		end
		return result
	end

	local ok, content = pcall(function()
		return read_file(filename)
	end)
	if not ok then
		error(string.format("file does not exist: %s", filename))
	end

	local package_lines = find_in_text(PACKAGE_QUERY, content)
	local package_name = (package_lines and package_lines[1]) or ""

	return package_name
end

return resolve_package_name
