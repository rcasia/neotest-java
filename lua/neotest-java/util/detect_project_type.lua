local compatible_path = require("neotest-java.util.compatible_path")
local scan = require("plenary.scandir")

--- Detect project type (maven | gradle | unknown)
--- @param root_dir string
--- @param scandir fun(path: string, opts?: table): string[]
--- @return "maven"|"gradle"|"unknown"
local function detect_project_type(root_dir, scandir)
	scandir = scandir or scan.scan_dir
	local files = scandir(compatible_path(root_dir), {
		hidden = false,
		add_dirs = false,
		depth = math.huge,
	}) or {}

	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)$")
		if name == "pom.xml" then
			return "maven"
		elseif name == "settings.gradle" or name == "settings.gradle.kts" then
			return "gradle"
		end
	end

	return "unknown"
end

return detect_project_type
