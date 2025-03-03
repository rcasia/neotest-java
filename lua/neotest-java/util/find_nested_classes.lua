---@param node_id string
---@return string
local function find_nested_classes(node_id)
	-- node.id contains something like: "com/example/MyTest.java::MyTest::MyInnerTest::test"
	local pattern = "::([^:]+)" -- will match all the nested classes and test method name
	local nested_classes = vim.iter(node_id:gmatch(pattern)):totable()

	return vim
		.iter(nested_classes)
		--
		:skip(1) -- skip the base class
		:rskip(1) -- skip the test method name
		:join("::")
end

return find_nested_classes
