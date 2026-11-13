local LspCompiler = require("neotest-java.core.spec_builder.compiler.lsp_compiler")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq
local async = require("tests.async_helpers").async
local args = { base_dir = Path("/path/to/project"), compile_mode = "incremental" }

local function compiler(client, opts)
	return LspCompiler(vim.tbl_extend("force", {
		client_provider = function(cwd)
			eq(args.base_dir, cwd)
			return client
		end,
		schedule = function(fn)
			fn()
		end,
		timeout_ms = 20,
	}, opts or {}))
end

describe("LSP compiler", function()
	for _, mode in ipairs({ "incremental", "full" }) do
		it(
			"awaits successful " .. mode .. " compilation",
			async(function()
				local callback, completed = nil, false
				local c = compiler({
					initialized = true,
					request = function(_, method, params, cb)
						eq("java/buildWorkspace", method)
						eq(mode == "full", params)
						callback = cb
						local timer = vim.uv.new_timer()
						timer:start(5, 0, function()
							eq(false, completed)
							timer:close()
							cb(nil, 1)
						end)
						return true, 42
					end,
				})
				eq(true, c.compile({ base_dir = args.base_dir, compile_mode = mode }))
				completed = true
				assert(callback)
				callback(nil, 2) -- late callback ignored after exactly-once completion
			end)
		)
	end

	for _, status in ipairs({ 0, 2, 3, false, "unexpected" }) do
		it(
			"rejects unsuccessful build status " .. tostring(status),
			async(function()
				local c = compiler({
					initialized = true,
					request = function(_, _, _, cb)
						cb(nil, status)
						return true
					end,
				})
				local ok, err = pcall(c.compile, args)
				eq(false, ok)
				assert(tostring(err):find("buildWorkspace status", 1, true))
			end)
		)
	end

	it("rejects an absent or uninitialized JDTLS client", function()
		for _, client in ipairs({ false, { initialized = false } }) do
			local ok, err = pcall(compiler(client).compile, args)
			eq(false, ok)
			assert(tostring(err):find("not initialized", 1, true))
		end
	end)

	for _, kind in ipairs({ "error", "throw", "reject", "timeout" }) do
		it(
			"settles request " .. kind,
			async(function()
				local c = compiler({
					initialized = true,
					request = function(_, _, _, cb)
						if kind == "error" then
							cb({ message = "build broken" })
						elseif kind == "throw" then
							error("request exploded")
						elseif kind == "reject" then
							return false
						end
						return true
					end,
				})
				local ok, err = pcall(c.compile, args)
				eq(false, ok)
				assert(tostring(err):find("compilation failed", 1, true))
			end)
		)
	end
end)
