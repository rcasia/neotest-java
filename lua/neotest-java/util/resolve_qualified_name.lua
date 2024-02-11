local function resolve_qualified_name(filename)
	local function find_in_text(raw_query, content)
		local query = vim.treesitter.query.parse("java", raw_query)

		local lang_tree = vim.treesitter.get_string_parser(content, "java")
		local root = lang_tree:parse()[1]:root()

		local result = ""
		for i, node, metadata in query:iter_captures(root, content, 0, -1) do
			result = vim.treesitter.get_node_text(node, content)
			break
		end
		return result
	end

	-- read the file
	local ok, lines = pcall(vim.fn.readfile, filename)
	if not ok then
		error(string.format("file does not exist: %s", filename))
	end

	-- transform the lines into a string
	local content = table.concat(lines, "\n")

	-- get the package name
	local package_query = [[

      ((package_declaration (scoped_identifier) @package.name))

      ((package_declaration (identifier) @package.name))

  ]]

	local class_name_query = [[
    ((class_declaration (identifier) @target))
  ]]

	local package_line = find_in_text(package_query, content)
	local name = find_in_text(class_name_query, content)

	return package_line .. "." .. name
end

return resolve_qualified_name
