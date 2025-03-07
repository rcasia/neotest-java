local log = require("neotest-java.logger")
local lsp = require("neotest-java.lsp")
local nio = require("nio")

---@param build_type string
local function run_build(build_type)
	local bufnr = nio.api.nvim_get_current_buf()
	local err, result = lsp.execute_command("workspace/executeCommand", {
		command = "java.project.getAll",
	}, bufnr)

	if result == nil or err ~= nil then
		log.warn(string.format("Unable to find any active projects", build_type))
	else
		local cwd = vim.fn.getcwd()
		local projects = vim.tbl_filter(function(p)
			local name = p and vim.uri_to_fname(p)
			return name and vim.startswith(name, cwd)
		end, result)

		if projects and #projects > 0 then
			err, result = lsp.execute_command("java/buildProjects", {
				identifiers = vim.tbl_map(function(project)
					return { uri = project }
				end, projects),
				isFullBuild = build_type,
			}, bufnr)

			local list = table.concat(projects, ",")
			if result == nil or err ~= nil then
				log.warn(string.format("Unable to build [%s] with [%s] mode", list, build_type))
			else
				log.info(string.format("Built projects [%s] with mode %s", list, build_type))
			end
		else
			log.warn(string.format("Unable to resolve project/s from cwd %s", cwd))
		end
	end

	return result
end

return run_build
