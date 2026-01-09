-- Fully-qualify parameter types for JUnit selectors
local function normalize_type_for_junit(t, package_name)
	-- trim/collapse
	t = t:gsub("%s+", "")
	-- detect varargs / array dims (strip and re-append later)
	local is_varargs = false
	if t:sub(-3) == "..." then
		is_varargs = true
		t = t:sub(1, -4)
	end
	local dims = 0
	while t:sub(-2) == "[]" do
		dims = dims + 1
		t = t:sub(1, -3)
	end

	-- strip generics
	t = t:gsub("<.->", "")

	local primitives = {
		boolean = true,
		byte = true,
		short = true,
		char = true,
		int = true,
		long = true,
		float = true,
		double = true,
		["void"] = true,
	}
	if primitives[t] then
		if is_varargs then
			dims = dims + 1
		end -- varargs primitive -> primitive[]
		return t .. string.rep("[]", dims)
	end

	local java_lang = {
		String = true,
		Object = true,
		Boolean = true,
		Integer = true,
		Double = true,
		Float = true,
		Long = true,
		Short = true,
		Character = true,
		Byte = true,
		Void = true,
	}
	local java_util = {
		List = true,
		Map = true,
		Set = true,
		Collection = true,
		Iterable = true,
		Deque = true,
		Queue = true,
		Optional = true,
	}

	local function convert_nested_dots_to_dollars(fqn)
		local pkg, classes = fqn:match("^([%l%d_%.]+)%.(.+)$")
		if not pkg then
			if fqn:match("^[A-Z]") then
				return fqn:gsub("%.", "$")
			end
			return fqn
		end
		classes = classes:gsub("%.", "$")
		return pkg .. "." .. classes
	end

	local qualified
	if t:find("%.") then
		local first = t:match("^([%w_]+)")
		if first and first:match("^[a-z]") then
			qualified = convert_nested_dots_to_dollars(t) -- already FQN package
		else
			qualified = (package_name and package_name ~= "" and (package_name .. "." .. t) or t)
			qualified = convert_nested_dots_to_dollars(qualified)
		end
	else
		if java_lang[t] then
			qualified = "java.lang." .. t
		elseif java_util[t] then
			qualified = "java.util." .. t
		elseif package_name and package_name ~= "" then
			qualified = package_name .. "." .. t
		else
			qualified = t
		end
		qualified = convert_nested_dots_to_dollars(qualified)
	end

	if is_varargs then
		dims = dims + 1
	end -- varargs reference -> one extra []
	return qualified .. string.rep("[]", dims)
end

local parameterized_test_method_id = function(position, parents, package_name, params)
	local test_name = position.name
	local normalized = {}
	for _, p in ipairs(params) do
		table.insert(normalized, normalize_type_for_junit(p, package_name))
	end
	test_name = string.format("%s(%s)", test_name, table.concat(normalized, ", "))

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
	return package_name ~= "" and (package_name .. "." .. namespace_string .. "#" .. test_name)
		or (namespace_string .. "#" .. test_name)
end

return parameterized_test_method_id
