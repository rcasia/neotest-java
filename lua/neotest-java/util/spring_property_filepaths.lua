local Path = require("neotest-java.model.path")

--- @param base_dirs neotest-java.Path[]
--- @return neotest-java.Path[]
local function generate_spring_property_filepaths(base_dirs)
	local prefix = "optional:"
	local scheme = "file:"
	local exts = { "yml", "yaml", "properties" }

	local locations = {}
	for _, base_dir in ipairs(base_dirs) do
		local bases = { base_dir.append("application"), base_dir.append("application-test") }
		for _, base in ipairs(bases) do
			for _, ext in ipairs(exts) do
				local location = Path(prefix .. scheme .. base.to_string() .. "." .. ext)
				table.insert(locations, location)
			end
		end
	end

	return locations
end

return generate_spring_property_filepaths
