local LspCompiler = require("neotest-java.core.spec_builder.compiler.native_lsp_compiler")
local Path = require("neotest-java.util.path")

local assertions = require("tests.assertions")
local eq = assertions.eq

describe("Native LSP compiler", function()
	it("works", function()
		local compiler = LspCompiler({
			client_provider = function(cwd)
				eq(Path("/path/to/project"), cwd)
				return {
					request_sync = function(_, params, opts)
						eq("java/buildWorkspace", params)
						eq({ forceRebuild = false }, opts)

						return {}
					end,
				}
			end,
		})

		compiler.compile({
			base_dir = Path("/path/to/project"),
			compile_mode = "incremental",
		})
	end)
end)
