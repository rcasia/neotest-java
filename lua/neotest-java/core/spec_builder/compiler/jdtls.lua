local logger = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local lib = require("neotest.lib")
local nio = require("nio")

-- --- @param bufnr number | nil
-- --- @return vim.lsp.Client
-- local function get_client(bufnr)
-- local client_future = nio.control.future()
-- nio.run(function()
-- local clients = vim.lsp.get_clients({ name = "jdtls", bufnr = bufnr })
-- client_future.set(clients and clients[1])
-- end)
-- return client_future:wait()
-- end

-- --- @param dir string
-- --- @return string | nil
-- local function find_any_java_file(dir)
-- return assert(
-- vim.iter(nio.fn.globpath(dir or ".", "**/*.java", false, true)):next(),
-- "No Java file found in the current directory."
-- )
-- end

-- --- @param path string
-- --- @return number bufnr
-- local function preload_file_for_lsp(path)
-- assert(path, "path cannot be nil")
-- local buf = vim.fn.bufadd(path) -- allocates buffer ID
-- vim.fn.bufload(path)            -- preload lines

local function get_current_project(working_directory)
    local bufnr = nio.api.nvim_get_current_buf()
    local err, result = lsp.execute_command("workspace/executeCommand", {
        command = "java.project.list",
        arguments = { vim.uri_from_fname(working_directory) }
    }, bufnr)
    assert(not err, vim.inspect(err))

    local projects = vim.tbl_filter(function(p)
        local path = vim.uri_to_fname(p.uri)
        return vim.startswith(path, working_directory)
    end, result)

    assert(projects and #projects == 1, vim.inspect(working_directory))
    return projects[1]
end

---@type NeotestJavaCompiler
local compiler = {
    build_workspace = function(args)
        local bufnr = nio.api.nvim_get_current_buf()
        local err, result = lsp.execute_command("java/buildWorkspace", args.compile_mode == "full", bufnr)
        assert(not err, vim.inspect(err))
        logger.info(string.format("Built workspace using %s build", args.compile_mode))

        local project = get_current_project(args.cwd);
        return result, project.name
    end,
    build_project = function(args)
        local bufnr = nio.api.nvim_get_current_buf()
        local project = get_current_project(args.cwd);

        local err, result = lsp.execute_command("java/buildProjects", {
            identifiers = { { uri = project.uri } },
            isFullBuild = args.compile_mode,
        }, bufnr)
        assert(not err, vim.inspect(err))
        lib.notify(string.format(
                "Built project/s %s using %s mode",
                project.name, args.compile_mode
            ),
            vim.log.levels.INFO)

        return result, project.name
    end
}

return compiler
