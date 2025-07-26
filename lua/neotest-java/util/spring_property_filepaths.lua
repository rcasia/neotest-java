local p = require("neotest-java.util.compatible_path")

--- @param base_dirs string[]
--- @return string[]
local function generate_spring_property_filepaths(base_dirs)
	local prefix = "optional:"
	local scheme = "file:"
	local exts = { "yml", "yaml", "properties" }

	local locations = {}
	for _, base_dir in ipairs(base_dirs) do
		local bases = { base_dir .. "/application", base_dir .. "/application-test" }
		for _, base in ipairs(bases) do
			for _, ext in ipairs(exts) do
				local location = p(prefix .. scheme .. base .. "." .. ext)
				table.insert(locations, location)
			end
		end
	end

	return locations
end

return generate_spring_property_filepaths
