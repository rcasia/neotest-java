local dir_scan = require("neotest-java.util.dir_scan")
local Path = require("neotest-java.model.path")

-- Build-marker file name patterns, reused as `dir_scan`'s search patterns
-- so we only collect entries we actually care about while walking the tree.
local MARKER_PATTERNS = {
	"pom%.xml$",
	"mvnw$",
	"mvnw%.cmd$",
	"settings%.gradle$",
	"settings%.gradle%.kts$",
	"build%.gradle$",
	"build%.gradle%.kts$",
	"gradlew$",
	"gradlew%.bat$",
}

--- Default recursive scandir, built on top of `util/dir_scan.lua`'s
--- existing `vim.uv.fs_scandir`-based walk, replacing the previous
--- `plenary.scandir` default (see #317). `dir_scan.scan` already filters
--- entries by `search_patterns` and returns a flat array of matching
--- `Path`s directly (not `{path, typ}` wrapper tables) — a directory
--- happening to be named exactly like one of our marker filenames is not
--- a realistic concern, so every match is treated as a file path.
--- @param root_str string
--- @return string[]
local function default_scandir(root_str)
	local matches = dir_scan(Path(root_str), { search_patterns = MARKER_PATTERNS })
	local files = {}
	for i, path in ipairs(matches) do
		files[i] = path:to_string()
	end
	return files
end

--- Detect project type (maven | gradle | unknown)
--- @param root_dir neotest-java.Path
--- @param scandir? fun(path: string, opts?: table): string[]
--- @param readdir? fun(path: string): string[]
--- @return "maven"|"gradle"|"unknown"
local function detect_project_type(root_dir, scandir, readdir)
	scandir = scandir or default_scandir
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
