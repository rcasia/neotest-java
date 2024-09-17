local logger = require("neotest-java.logger")

local function take_just_the_dependency(line)
	-- Pattern to match groupId, artifactId, and version
	local pattern = "([%a][%w_%-%.]*):([%a][%w_%-%.]*)(.-):([%d][%w_%-%.]*)"
	local old_version, new_version = line:match("(%d+%.%d+%.%d+) %-+> (%d+%.%d+%.%d+)")
	local groupId, artifactId, _, version = line:match(pattern)
	version = new_version or version
	if groupId and artifactId and version then
		return groupId .. ":" .. artifactId .. ":" .. version
	else
		return nil
	end
end

return take_just_the_dependency
