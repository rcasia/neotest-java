local Path = require("neotest-java.model.path")

local assertions = require("tests.assertions")
local eq = assertions.eq

local LspCompiler = require("neotest-java.core.spec_builder.compiler.lsp_compiler")

describe("LSP compiler", function()
	it("forwards to the language server gateway", function()
		local seen_opts
		local compiler = LspCompiler({
			---@diagnostic disable-next-line: missing-fields
			language_server = {
				compile = function(opts)
					seen_opts = opts
				end,
			},
		})

		compiler.compile({
			base_dir = Path("/path/to/project"),
			compile_mode = "incremental",
		})

		eq({ base_dir = Path("/path/to/project"), compile_mode = "incremental" }, seen_opts)
	end)
end)
