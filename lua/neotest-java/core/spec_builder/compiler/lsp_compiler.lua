local nio = require("nio")

--- @class neotest-java.BuildClient
--- @field initialized boolean
--- @field request fun(self: table, method: string, params: boolean, callback: fun(err: any, status: any)): boolean, number?
--- @field cancel_request fun(self: table, request_id: number)

--- @class neotest-java.LspCompilerDeps
--- @field client_provider fun(cwd: neotest-java.Path): neotest-java.BuildClient
--- @field schedule? fun(fn: fun())
--- @field timeout_ms? number

--- JDTLS java/buildWorkspace returns CompileWorkspaceStatus:
--- FAILED=0, SUCCEED=1, WITHERROR=2, CANCELLED=3 (not classpath data).
--- @param deps neotest-java.LspCompilerDeps
--- @return NeotestJavaCompiler
local function LspCompiler(deps)
	return {
		compile = function(args)
			local client = deps.client_provider(args.base_dir)
			assert(client and client.initialized, "JDTLS is not initialized for " .. tostring(args.base_dir))
			local result = nio.control.future()
			local timer = assert(vim.uv.new_timer())
			local request_id
			local function finish(err, status)
				if result.is_set() then
					return
				end
				timer:stop()
				timer:close()
				if err then
					result.set_error("JDTLS compilation failed: " .. vim.inspect(err))
				elseif status ~= 1 then
					result.set_error("JDTLS compilation failed (buildWorkspace status " .. tostring(status) .. ")")
				else
					result.set(true)
				end
			end
			timer:start(deps.timeout_ms or 120000, 0, function()
				finish("Timed out waiting for java/buildWorkspace")
				if request_id then
					vim.schedule(function()
						client:cancel_request(request_id)
					end)
				end
			end)
			local schedule = deps.schedule or vim.schedule
			schedule(function()
				if result.is_set() then
					return
				end
				local ok, accepted, id =
					pcall(client.request, client, "java/buildWorkspace", args.compile_mode == "full", finish)
				request_id = id
				if not ok or not accepted then
					finish(ok and "java/buildWorkspace request rejected" or accepted)
				end
			end)
			return result.wait()
		end,
	}
end

return LspCompiler
