local compatible_path = require("neotest-java.util.compatible_path")

local function compatible_path_parent(path)
	local confirmed_path = compatible_path(path)
	return confirmed_path:match("^(.*)[/\\][^/\\]+$") or confirmed_path
end
return compatible_path_parent
