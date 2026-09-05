local assertions = require("tests.assertions")
local eq = assertions.eq

local Path = require("neotest-java.model.path")
local detect_project_type = require("neotest-java.util.detect_project_type")

--- Real-filesystem integration coverage for `detect_project_type`'s
--- fallback path: a genuine multi-directory layout with no build markers
--- at the top level, scanned by the *real* `plenary.scandir` (no stubs
--- injected), exactly as it runs in production. This is the exact
--- behavior a future non-plenary implementation (see #317) must preserve.
describe("detect_project_type (real filesystem integration)", function()
	local root_dir

	before_each(function()
		root_dir = vim.fn.tempname()
		vim.fn.mkdir(root_dir, "p")
	end)

	after_each(function()
		vim.fn.delete(root_dir, "rf")
	end)

	it("finds a maven marker nested several directories deep via the real recursive scan", function()
		local nested_dir = root_dir .. "/module-a/src/main/java/com/example"
		vim.fn.mkdir(nested_dir, "p")
		-- No markers at the top level, forcing the fallback path.
		vim.fn.writefile({}, root_dir .. "/module-a/pom.xml")

		local result = detect_project_type(Path(root_dir))

		eq("maven", result)
	end)

	it("finds a gradle marker nested in a sibling module via the real recursive scan", function()
		vim.fn.mkdir(root_dir .. "/module-a", "p")
		vim.fn.mkdir(root_dir .. "/module-b", "p")
		vim.fn.writefile({}, root_dir .. "/module-b/build.gradle")

		local result = detect_project_type(Path(root_dir))

		eq("gradle", result)
	end)

	it("returns 'unknown' for a real nested directory tree with no build markers anywhere", function()
		vim.fn.mkdir(root_dir .. "/src/main/java/com/example", "p")
		vim.fn.writefile({}, root_dir .. "/src/main/java/com/example/App.java")
		vim.fn.writefile({}, root_dir .. "/README.md")

		local result = detect_project_type(Path(root_dir))

		eq("unknown", result)
	end)

	it("uses the fast top-level path (no recursive scan needed) when a marker is at the root", function()
		vim.fn.writefile({}, root_dir .. "/pom.xml")
		vim.fn.mkdir(root_dir .. "/some/deeply/nested/dir", "p")
		vim.fn.writefile({}, root_dir .. "/some/deeply/nested/dir/build.gradle")

		-- Even though a gradle marker exists deeper in the tree, the
		-- top-level pom.xml should win via the fast path.
		local result = detect_project_type(Path(root_dir))

		eq("maven", result)
	end)
end)
