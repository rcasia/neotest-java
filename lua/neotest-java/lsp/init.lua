local log = require("neotest-java.logger")
local nio = require("nio")

local function coc_command(id, params, _)
    -- fix: this can be cached to avoid fetching it, however it is specific and can be overriden on a workspace folder level,
    -- therefore extra care has to be taken when caching the settings, otherwise they will end up out of sync or invalid
    local settings = nio.fn["coc#util#get_config"]("java")

    if params == nil then
        params = {}
    end
    if type(params) ~= "table" then
        params = { params }
    end
    local ok_services, services = pcall(nio.fn.CocAction, "services")
    services = ok_services and vim.tbl_filter(function(service)
        return service and service.state == "running" and service.id == "java"
    end, services) or {}
    assert(#services > 0, "there is no jdtls client attached")

    local ok_request, result = pcall(nio.fn.CocRequest, "java", id, params)
    if not ok_request or not result then
        log.warn(
            string.format(
                "Unable to run lsp request %s with payload %s", id, vim.inspect(params)
            )
        )
    end
    local err = not ok_request and result ~= vim.NIL and { message = result } or nil
    return err, result, settings
end

local function lsp_command(id, params, bufnr)
    local clients = vim.lsp.get_clients({ name = "jdtls" })
    assert(#clients > 0, "there is no jdtls client attached")

    local response, error = clients[1].request_sync(id, params, 5000, bufnr)
    if error then
        log.warn(
            string.format(
                "Unable to run lsp command %s with payload %s", id, vim.inspect(params)
            )
        )
    end
    return error, response and response.result, clients[1].config.settings.java
end

local function execute_command(id, params, bufnr)
    if vim.g.did_coc_loaded ~= nil then
        return coc_command(id, params, bufnr)
    else
        return lsp_command(id, params, bufnr)
    end
end

return {
    execute_command = execute_command,
}
