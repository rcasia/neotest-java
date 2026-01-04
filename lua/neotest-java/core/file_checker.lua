local Path = require("neotest-java.model.path")

--- @class neotest-java.FileChecker
--- @field is_test_file fun(file_path: string): boolean

--- @class neotest-java.FileCheckerDependencies
--- @field root_getter fun(): neotest-java.Path
--- @field patterns string[]

--- @param dependencies neotest-java.FileCheckerDependencies
--- @return neotest-java.FileChecker
local FileChecker = function(dependencies)
	return {
		is_test_file = function(file_path)
			--- @type neotest-java.Path
			local my_path = Path(file_path)
			local base_dir = dependencies.root_getter()

			local relative_path = my_path:make_relative(base_dir)
			if relative_path:contains("main") then
				return false
			end

			for _, re in ipairs(dependencies.patterns) do
				local name_without_extension = my_path:name():gsub("%.java$", "")
				if name_without_extension:match(re) then
					return true
				end
			end
			return false
		end,
	}
end

return FileChecker
