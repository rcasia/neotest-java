--- @param position neotest.Position
--- @param parents neotest.Position[]
--- @param package_name string
local namespace_id = function(position, parents, package_name)
	local namespace_string = vim
		.iter(parents)
		--- @param pos neotest.Position
		:filter(function(pos)
			return pos.type == "namespace"
		end)
		:map(function(pos)
			return pos.name
		end)
		:join("$")

	if namespace_string == "" then
		return package_name ~= "" and (package_name .. "." .. position.name) or position.name
	end

	return package_name ~= "" and (package_name .. "." .. namespace_string .. "$" .. position.name)
		or (namespace_string .. "$" .. position.name)
end

return namespace_id
