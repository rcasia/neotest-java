local RootFinder = require("neotest-java.core.root_finder")

SpecBuilder = {}
---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args)
	local position = args.tree:data()

	local root = RootFinder.findRoot(position.path)
	local relative_path = position.path:sub(#root + 2)
	local test_reference = SpecBuilder.findJavaReference(relative_path, position.name)

	-- TODO: add support for multiple modules projects
	local command = vim.tbl_flatten({
		"mvn",
		"test",
		"-Dtest=" .. test_reference,
	})

	return {
		command = table.concat(command, " "),
		cwd = root,
	}
end

function SpecBuilder.findJavaReference(relative_path, name)
	return relative_path:gsub("src/test/java/", ""):gsub("/", "."):gsub(".java", "") .. "#" .. name
end

return SpecBuilder
