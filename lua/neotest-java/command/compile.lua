local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

---@param compilation_type string
local function run_compile(compilation_type)
    local bufnr = nio.api.nvim_get_current_buf()
    local err, result = lsp.execute_command("java/buildWorkspace", compilation_type == "full", bufnr)
    if result == nil or err ~= nil then
        log.warn(string.format("Unable to build with [%s] mode", compilation_type))
    else
        log.info(string.format("Built workspace with mode %s", compilation_type))
    end

    return result
end

return run_compile
