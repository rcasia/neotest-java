local ignore_patterns = require("neotest-java.types.ignore_path_patterns")

-- Function to determine if a path should be ignored in Maven or Gradle projects
local function should_ignore_path(path)
	-- Normalize the path separators to '/'
	local normalized_path = path:gsub("\\", "/")

	for _, pattern in ipairs(ignore_patterns) do
		if normalized_path:match(pattern) then
			return true -- Path should be ignored
		end
	end
	return false -- Path should not be ignored
end

return should_ignore_path
