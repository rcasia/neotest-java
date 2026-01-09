-- =============================================================================
-- CONFIGURATION & CONSTANTS
-- =============================================================================

local PRIMITIVES = {
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

local JAVA_LANG_CLASSES = {
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

local JAVA_UTIL_CLASSES = {
	List = true,
	Map = true,
	Set = true,
	Collection = true,
	Iterable = true,
	Deque = true,
	Queue = true,
	Optional = true,
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

--- Removes <Generic> information (Type Erasure)
--- @param type_str string
--- @return string
local function strip_generics(type_str)
	local result = type_str:gsub("<.->", "")
	return result
end

--- Formatting Inner Classes: The JVM uses '$' for inner classes (Outer$Inner),
--- but source code uses dots (Outer.Inner).
--- Heuristic: Split the string into the 'package' (lowercase) and 'classes' (TitleCase).
local function format_inner_classes(fqn)
	-- Attempt to split into (package)(classes)
	-- Pattern: starts with lowercase/dots -> package
	local pkg, classes = fqn:match("^([%l%d_%.]+)%.(.+)$")

	if not pkg then
		-- If no package detected, check if it looks like a class (starts with Uppercase)
		if fqn:match("^[A-Z]") then
			return fqn:gsub("%.", "$")
		end
		return fqn
	end

	-- Replace dots with dollars only in the class portion
	classes = classes:gsub("%.", "$")
	return pkg .. "." .. classes
end

--- Parses array brackets and varargs, returning the base type and dimension count.
--- @param type_str string
--- @return string base_type, number dimensions
local function extract_array_dimensions(type_str)
	local dims = 0

	-- Handle varargs (...)
	if type_str:sub(-3) == "..." then
		dims = dims + 1
		type_str = type_str:sub(1, -4)
	end

	-- Handle standard array brackets []
	-- We loop to strip them off one by one
	while type_str:sub(-2) == "[]" do
		dims = dims + 1
		type_str = type_str:sub(1, -3)
	end

	return type_str, dims
end

--- Resolves the Fully Qualified Name (FQN) for a base type.
local function resolve_fqn(base_type, package_name)
	-- 1. Check if already fully qualified or explicitly imported
	if base_type:find("%.") then
		local first_segment = base_type:match("^([%w_]+)")
		-- If it starts with lowercase, assume it's already a full package path
		if first_segment and first_segment:match("^[a-z]") then
			return format_inner_classes(base_type)
		end
		-- Otherwise, prepend current package
		local qualified = (package_name and package_name ~= "") and (package_name .. "." .. base_type) or base_type
		return format_inner_classes(qualified)
	end

	-- 2. Check Standard Java Libraries
	if JAVA_LANG_CLASSES[base_type] then
		return format_inner_classes("java.lang." .. base_type)
	elseif JAVA_UTIL_CLASSES[base_type] then
		return format_inner_classes("java.util." .. base_type)
	end

	-- 3. Default: Prepend package name
	if package_name and package_name ~= "" then
		local qualified = package_name .. "." .. base_type
		return format_inner_classes(qualified)
	end

	return format_inner_classes(base_type)
end

-- =============================================================================
-- MAIN LOGIC
-- =============================================================================

--- Fully-qualify parameter types for JUnit selectors
local function normalize_type_for_junit(type_raw, package_name)
	-- 1. Cleanup whitespace
	local t = type_raw:gsub("%s+", "")

	-- 2. Handle Arrays and Varargs
	local base_type, dims = extract_array_dimensions(t)

	-- 3. Strip Generics (List<String> -> List)
	base_type = strip_generics(base_type)

	-- 4. Handle Primitives (early return, no FQN needed)
	if PRIMITIVES[base_type] then
		-- If it was a vararg primitive (int...), it becomes an array (int[])
		-- Logic: extract_array_dimensions already incremented 'dims' for '...',
		-- so we just append the brackets.
		return base_type .. string.rep("[]", dims)
	end

	-- 5. Resolve FQN for Objects
	local fqn = resolve_fqn(base_type, package_name)

	-- 6. Re-assemble array brackets
	-- Note: Varargs for objects (String...) are treated as arrays (String[]) in JVM signatures
	return fqn .. string.rep("[]", dims)
end

local function parameterized_test_method_id(position, parents, package_name, params)
	local test_name = position.name

	-- Normalize all parameters
	local normalized_params = {}
	for _, p in ipairs(params) do
		table.insert(normalized_params, normalize_type_for_junit(p, package_name))
	end

	-- Format: testName(p1, p2)
	local method_signature = string.format("%s(%s)", test_name, table.concat(normalized_params, ", "))

	-- Build Class Path (Outer$Inner)
	-- Filters the Neotest tree for 'namespace' nodes and joins them
	local class_path = vim.iter(parents)
		:filter(function(pos)
			return pos.type == "namespace"
		end)
		:map(function(pos)
			return pos.name
		end)
		:join("$")

	-- Combine: package.ClassPath#methodSignature
	if package_name and package_name ~= "" then
		return string.format("%s.%s#%s", package_name, class_path, method_signature)
	end

	return string.format("%s#%s", class_path, method_signature)
end

return parameterized_test_method_id
