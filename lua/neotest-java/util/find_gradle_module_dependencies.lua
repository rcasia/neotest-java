local read_file = require("neotest-java.util.read_file")

---@param filepath string
local function find_gradle_module_dependencies(filepath)
	local query = [[
(
  (function_call
    function: (identifier) @func (#eq? @func "project")
		args: (argument_list (string (string_content) @module ))
  )
.
	(closure
		(juxt_function_call
			function: (identifier) @deps (#eq? @deps "dependencies")
			args: (argument_list
			  (closure
				  (juxt_function_call
						function: (identifier) @compile (#eq? @compile "compile")
						args: (argument_list
							(function_call
								args: (argument_list (string (string_content) @module )
							)
						 )
						)
					)
				)
			)

		)
	)
)
]]

	local function find_in_text(raw_query, content)
		local _query = vim.treesitter.query.parse("groovy", raw_query)

		local lang_tree = vim.treesitter.get_string_parser(content, "groovy")
		local root = lang_tree:parse()[1]:root()

		local results = {}
		for _, node, _ in _query:iter_captures(root, content, 0, -1) do --luacheck: ignore 512 loop is executed at most once
			results[#results + 1] = vim.treesitter.get_node_text(node, content)
		end
		return results
	end

	-- read the file
	local ok, content = pcall(function()
		return read_file(filepath)
	end)
	if not ok then
		error(string.format("file does not exist: %s", filepath))
	end

	local nodes = find_in_text(query, content)
	local results = {}
	local curr_module = ""
	for i, node_text in ipairs(nodes) do
		if string.sub(node_text, 1, 1) == ":" and nodes[i - 1] == "project" then
			local _node_text = string.sub(node_text, 2)
			results[_node_text] = {}
			curr_module = _node_text
		elseif string.sub(node_text, 1, 1) == ":" then
			local _node_text = string.sub(node_text, 2)
			table.insert(results[curr_module], _node_text)
		end
	end

	return results
end

return find_gradle_module_dependencies
