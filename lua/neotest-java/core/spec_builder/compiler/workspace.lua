local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

---@param build_type string
local function run_build(build_type)
	local bufnr = nio.api.nvim_get_current_buf()
	local err, result = lsp.execute_command("java/buildWorkspace", build_type == "full", bufnr)
	if result == nil or err ~= nil then
		log.warn(string.format("Unable to build workspace with [%s] mode", build_type))
	else
		log.info(string.format("Built entire workspace with mode %s", build_type))
	end

	return result
end

return run_build
