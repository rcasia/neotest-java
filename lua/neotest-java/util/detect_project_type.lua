local scan = require("plenary.scandir")

--- Detect project type (maven | gradle | unknown)
--- @param root_dir neotest-java.Path
--- @param scandir? fun(path: string, opts?: table): string[]
--- @param readdir? fun(path: string): string[]
--- @return "maven"|"gradle"|"unknown"
local function detect_project_type(root_dir, scandir, readdir)
	scandir = scandir or scan.scan_dir
	readdir = readdir or vim.fn.readdir

	local root_str = root_dir:to_string()

	-- 1. Fast path: check top-level directory first
	if vim.fn.isdirectory(root_str) == 1 then
		local ok, top_files = pcall(readdir, root_str)
		if ok and type(top_files) == "table" and #top_files > 0 then
			local has_maven = false
			local has_gradle = false

			for _, name in ipairs(top_files) do
				if name == "pom.xml" or name == "mvnw" or name == "mvnw.cmd" then
					has_maven = true
				elseif
					name == "settings.gradle"
					or name == "settings.gradle.kts"
					or name == "build.gradle"
					or name == "build.gradle.kts"
					or name == "gradlew"
					or name == "gradlew.bat"
				then
					has_gradle = true
				end
			end

			if has_maven then
				return "maven"
			elseif has_gradle then
				return "gradle"
			end
		end
	end

	-- 2. Fallback: scan subdirectories if top-level search yielded no match
	local ok, files = pcall(scandir, root_str, {
		hidden = false,
		add_dirs = false,
		depth = math.huge,
	})
	files = (ok and files) and files or {}

	local has_maven = false
	local has_gradle = false

	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)$")
		if name == "pom.xml" or name == "mvnw" or name == "mvnw.cmd" then
			has_maven = true
		elseif
			name == "settings.gradle"
			or name == "settings.gradle.kts"
			or name == "build.gradle"
			or name == "build.gradle.kts"
			or name == "gradlew"
			or name == "gradlew.bat"
		then
			has_gradle = true
		end
	end

	if has_maven then
		return "maven"
	elseif has_gradle then
		return "gradle"
	end

	return "unknown"
end

return detect_project_type
