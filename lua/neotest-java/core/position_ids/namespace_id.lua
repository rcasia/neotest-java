--- @param str string
--- @return boolean
local not_empty = function(str)
	return str ~= nil and str ~= ""
end

--- @param str string
--- @return boolean
local is_empty = function(str)
	return str == nil or str == ""
end

---@param position neotest.Position
---@return boolean
local is_namespace = function(position)
	return position.type == "namespace"
end

--- @param key string
--- @return fun(t: table): any
local property = function(key)
	return function(t)
		assert(type(t) == "table", "Expected a table")
		return t[key]
	end
end

--- @param position neotest.Position
--- @param parents neotest.Position[]
--- @param package_name string
local namespace_id = function(position, parents, package_name)
	local namespace_string = vim
		--
		.iter(parents)
		:filter(is_namespace)
		:map(property("name"))
		:join("$")

	if is_empty(namespace_string) then
		return vim
			--
			.iter({ package_name, position.name })
			:filter(not_empty)
			:join(".")
	end

	return vim
		--
		.iter({ package_name, namespace_string .. "$" .. position.name })
		:filter(not_empty)
		:join(".")
end

return namespace_id
