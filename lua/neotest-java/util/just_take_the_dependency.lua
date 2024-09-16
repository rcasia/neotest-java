local logger = require("neotest-java.logger")

local function take_just_the_dependency(line)
	-- Pattern to match groupId, artifactId, and version
	local pattern = "([%a][%w_%-%.]*):([%a][%w_%-%.]*)(.-):([%d][%w_%-%.]*)"
	local groupId, artifactId, _, version = line:match(pattern)
	if groupId and artifactId and version then
		logger.debug("Matched dependency: " .. groupId .. ":" .. artifactId .. ":" .. version)
		return groupId .. ":" .. artifactId .. ":" .. version
	else
		logger.debug("Failed to match dependency in line: " .. line)
		return nil
	end
end

return take_just_the_dependency
