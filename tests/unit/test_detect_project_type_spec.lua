local assertions = require("tests.assertions")
local eq = assertions.eq

local Path = require("neotest-java.model.path")
local detect_project_type = require("neotest-java.util.detect_project_type")

describe("detect_project_type", function()
	describe("fast path (top-level readdir)", function()
		it("detects maven via pom.xml at the top level", function()
			local readdir = function(_)
				return { "pom.xml", "src" }
			end
			-- scandir should never be reached for the fast path to succeed
			local scandir = function()
				error("scandir should not be called when the fast path finds a match")
			end

			local result = detect_project_type(Path(vim.uv.os_tmpdir()), scandir, readdir)

			eq("maven", result)
		end)

		it("detects gradle via build.gradle at the top level", function()
			local readdir = function(_)
				return { "build.gradle", "src" }
			end
			local scandir = function()
				error("scandir should not be called when the fast path finds a match")
			end

			local result = detect_project_type(Path(vim.uv.os_tmpdir()), scandir, readdir)

			eq("gradle", result)
		end)

		it("prefers maven over gradle when both markers are present at the top level", function()
			local readdir = function(_)
				return { "pom.xml", "build.gradle" }
			end
			local scandir = function()
				error("scandir should not be called when the fast path finds a match")
			end

			local result = detect_project_type(Path(vim.uv.os_tmpdir()), scandir, readdir)

			eq("maven", result)
		end)

		it("recognizes all maven marker file names (pom.xml, mvnw, mvnw.cmd)", function()
			for _, marker in ipairs({ "pom.xml", "mvnw", "mvnw.cmd" }) do
				local readdir = function(_)
					return { marker }
				end
				local scandir = function()
					error("scandir should not be called when the fast path finds a match")
				end

				eq("maven", detect_project_type(Path(vim.uv.os_tmpdir()), scandir, readdir))
			end
		end)

		it(
			"recognizes all gradle marker file names (settings.gradle[.kts], build.gradle[.kts], gradlew[.bat])",
			function()
				for _, marker in ipairs({
					"settings.gradle",
					"settings.gradle.kts",
					"build.gradle",
					"build.gradle.kts",
					"gradlew",
					"gradlew.bat",
				}) do
					local readdir = function(_)
						return { marker }
					end
					local scandir = function()
						error("scandir should not be called when the fast path finds a match")
					end

					eq("gradle", detect_project_type(Path(vim.uv.os_tmpdir()), scandir, readdir))
				end
			end
		)
	end)

	describe("fallback path (recursive scandir)", function()
		it("falls back to scandir when readdir errors (e.g. directory does not exist)", function()
			local readdir = function(_)
				error("boom: directory not found")
			end
			local scandir_called_with = nil
			local scandir = function(root_str, opts)
				scandir_called_with = { root_str = root_str, opts = opts }
				return { root_str .. "/nested/pom.xml" }
			end

			local result = detect_project_type(Path("/fake/root"), scandir, readdir)

			eq("maven", result)
			assert(scandir_called_with ~= nil, "scandir should have been called as a fallback")
			eq(Path("/fake/root"):to_string(), scandir_called_with.root_str)
		end)

		it("falls back to scandir when the top-level directory has no marker files", function()
			local readdir = function(_)
				return { "README.md" }
			end
			local scandir = function(root_str, _)
				return { root_str .. "/module-a/build.gradle" }
			end

			local result = detect_project_type(Path("/fake/root"), scandir, readdir)

			eq("gradle", result)
		end)

		it("falls back to scandir when the top-level directory is empty", function()
			local readdir = function(_)
				return {}
			end
			local scandir = function(root_str, _)
				return { root_str .. "/deep/nested/dir/pom.xml" }
			end

			local result = detect_project_type(Path("/fake/root"), scandir, readdir)

			eq("maven", result)
		end)

		it("prefers maven over gradle when both markers are found in the recursive scan", function()
			local readdir = function(_)
				return {}
			end
			local scandir = function(root_str, _)
				return {
					root_str .. "/module-a/build.gradle",
					root_str .. "/module-b/pom.xml",
				}
			end

			local result = detect_project_type(Path("/fake/root"), scandir, readdir)

			eq("maven", result)
		end)

		it("returns 'unknown' when neither readdir nor the recursive scan find any marker", function()
			local readdir = function(_)
				return { "README.md" }
			end
			local scandir = function(_, _)
				return { "/fake/root/notes.txt" }
			end

			local result = detect_project_type(Path("/fake/root"), scandir, readdir)

			eq("unknown", result)
		end)

		it("returns 'unknown' when scandir itself errors", function()
			local readdir = function(_)
				return {}
			end
			local scandir = function(_, _)
				error("scandir exploded")
			end

			local result = detect_project_type(Path("/fake/root"), scandir, readdir)

			eq("unknown", result)
		end)

		it("passes recursive scan options (hidden=false, add_dirs=false, depth=math.huge)", function()
			local readdir = function(_)
				return {}
			end
			--- @type { hidden: boolean, add_dirs: boolean, depth: number } | nil
			local captured_opts = nil
			local scandir = function(_, opts)
				captured_opts = opts
				return {}
			end

			detect_project_type(Path("/fake/root"), scandir, readdir)

			assert(captured_opts ~= nil, "scandir should have been called with opts")
			eq(false, captured_opts.hidden)
			eq(false, captured_opts.add_dirs)
			eq(math.huge, captured_opts.depth)
		end)
	end)
end)
