local compiler = require("neotest-java.core.spec_builder.compiler.native_lsp_compiler")
local Path = require("neotest-java.util.path")

local assertions = require("tests.assertions")
local eq = assertions.eq
local it = require("nio").tests.it

describe("Native LSP compiler", function()
	it("works", function()
		compiler.compile({
			cwd = Path("/path/to/project"),
			classpath_file_dir = "/path/to/classpath/dir",
			compile_mode = "incremental",
			dependencies = {
				client_provider = function(cwd)
					eq(Path("/path/to/project"), cwd)
					return {
						request = function(_, params, opts)
							eq("java/buildWorkspace", params)
							eq({ forceRebuild = false }, opts)
						end,
					}
				end,
			},
		})
	end)
end)
