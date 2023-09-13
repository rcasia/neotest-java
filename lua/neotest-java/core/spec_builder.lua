local RootFinder = require("neotest-java.core.root_finder")

SpecBuilder = {}
---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args)
	local position = args.tree:data()

	local root = RootFinder.findRoot(position.path)
	local relative_path = position.path:sub(#root + 2)
	local test_reference = SpecBuilder.findJavaReference(relative_path, position.name)
	local is_integration_test = string.find(position.path, "IT.java", 1, true)

	-- TODO: add support for multiple modules projects
	local command_table = {}
	if is_integration_test then
		command_table = vim.tbl_flatten({
			"mvn",
			"clean",
			"verify",
			"-Dtest=" .. test_reference,
		})
	else
		command_table = vim.tbl_flatten({
			"mvn",
			"clean",
			"test",
			"-Dtest=" .. test_reference,
		})
	end

	local command = table.concat(command_table, " ")
	-- TODO: add debug logger
	-- print("Running command: " .. command)

	return {
		command = command,
		cwd = root,
		symbol = position.name,
	}
end

function SpecBuilder.findJavaReference(relative_path, name)
	-- if name contains java, then it's a class
	if string.find(name, ".java", 1, true) then
		return relative_path:gsub("src/test/java/", ""):gsub("/", "."):gsub(".java", "")
	end

	return relative_path:gsub("src/test/java/", ""):gsub("/", "."):gsub(".java", "") .. "#" .. name
end

return SpecBuilder
