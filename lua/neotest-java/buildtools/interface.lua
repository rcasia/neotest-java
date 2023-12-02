---@class neotest-java.BuildTool
---@field name string
---@field wrapper string
---@field global_binary string
---@field project_files table<string>
---@field test_src string
---@field reports_dir string
local BuildTool = {}

---@param command_builder CommandBuilder
---@return table<string>
function BuildTool.build_command(command_builder) end
