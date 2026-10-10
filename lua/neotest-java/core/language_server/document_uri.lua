local Path = require("neotest-java.model.path")

--- Resolves a representative test document URI for language server requests.
---
--- Architectural Rationale:
--- Unlike Eclipse JDTLS which accepts workspace root paths and an explicit `{ scope = "test" }`
--- parameter, IntelliJ LSP (intellij-lsp.nvim) derives project scope strictly from the document URI
--- passed to commands like `intellij.java.resolveLaunch` and `intellij.java.resolveBuildCommand`.
---
--- When passed a directory or project root URI, IntelliJ LSP defaults to production scope:
---   - Classpath only contains `target/classes` and runtime dependencies (missing test libraries).
---   - Build command defaults to production compile (e.g. `mvn compile`).
---
--- When passed an actual test file document URI (e.g. under `src/test/**/*.java`), IntelliJ LSP correctly
--- resolves test scope:
---   - Classpath includes `target/test-classes` and all test dependencies (JUnit, Mockito, etc.).
---   - Build command compiles test sources (e.g. `mvn test-compile`).
---
--- @param base_dir neotest-java.Path Target directory or Java file path
--- @param globpath? fun(dir: string, pattern: string, nosuf: boolean, list: boolean): string[] Injectable globpath function for unit testing
--- @return string uri Valid file URI formatted via vim.uri_from_fname
local function resolve_test_document_uri(base_dir, globpath)
	local path_str = base_dir:to_string()
	if path_str:match("%.java$") then
		return vim.uri_from_fname(path_str)
	end

	-- Use nio.fn.globpath where available to avoid Neovim E5560 (fast-event context)
	-- errors when resolving files within an async/coroutine execution context.
	local function safe_glob(pattern)
		if globpath then
			return globpath(path_str, pattern, false, true)
		end
		local ok, nio = pcall(require, "nio")
		if ok and nio.fn and nio.fn.globpath then
			local success, res = pcall(nio.fn.globpath, path_str, pattern, false, true)
			if success and type(res) == "table" then
				return res
			end
		end
		local success, res = pcall(vim.fn.globpath, path_str, pattern, false, true)
		if success and type(res) == "table" then
			return res
		end
		return {}
	end

	local test_files = safe_glob("src/test/**/*.java")
	if test_files and #test_files > 0 then
		return vim.uri_from_fname(test_files[1])
	end

	local any_tests = safe_glob("**/*Test*.java")
	if any_tests and #any_tests > 0 then
		return vim.uri_from_fname(any_tests[1])
	end

	return vim.uri_from_fname(path_str)
end

return resolve_test_document_uri
