local log = require("neotest-java.logger")
local nio = require("nio")

-- table that holds the language server settings, this is mostly done for interfacing with coc.nvim, since native neovim lsp clients hold their settings in the clients table
local SETTINGS = {}

local function execute_command(command, bufnr)
    if vim.g.did_coc_loaded ~= nil then
        -- cache the settings in case we use coc, since there is no way to obtain the client's settings
        -- directly from the coc.nvim api, unlike with native lsp
        SETTINGS = nio.fn["coc#util#get_config"]("java")
    else
        -- native lsp settings are contained in the client table, we are going to use those when executing
        -- the native client request sync call.
        SETTINGS = {}
    end

    if vim.g.did_coc_loaded ~= nil then
        if not command.arguments then
            command.arguments = {}
        end
        if type(command.arguments) ~= "table" then
            command.arguments = { command.arguments }
        end
        local ok, result = pcall(nio.fn.CocAction, "runCommand", command.command, unpack(command.arguments))
        if not ok or not result then
            log.warn(string.format("Unable to run lsp %s command with payload %s", command.command,
                vim.inspect(command.arguments)))
        end
        local error = not ok and result ~= vim.NIL and { message = result } or nil
        return error, result, {
            -- adapter for the native lsp client talbe format, to simplify external clients using this interface to talk to the lsp client, which ever it happens to be
            name = "jdtls",
            config = {
                settings = {
                    java = SETTINGS,
                },
            },
        }
    else
        local clients = {}
        for _, c in pairs(vim.lsp.get_clients({ bufnr = bufnr }) or {}) do
            local command_provider = c.server_capabilities.executeCommandProvider
            local commands = type(command_provider) == "table" and command_provider.commands or {}
            if vim.tbl_contains(commands, command.command) then
                table.insert(clients, c)
            end
        end
        if vim.tbl_count(clients) == 0 then
            log.warn(string.format("Unable to find lsp client that supports %s", command.command))
        else
            local response, error = clients[1].request_sync("workspace/executeCommand", command)
            if error then
                log.warn(string.format("Unable to run lsp %s command with payload %s", command.command,
                    vim.sinepct(command.arguments)))
            end
            return error, response.result, clients[1]
        end
    end
end

return {
    execute_command = execute_command
}
