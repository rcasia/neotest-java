local File = require("neotest.lib.file")

---@param filepath string
---@param content string
local function write_file(filepath, content)
	-- for os compatibibility
	local compatible_path = filepath:gsub("\\", File.sep):gsub("/", File.sep)

	--write manifest file
	local file = io.open(compatible_path, "w") or error("Could not open file for writing: " .. compatible_path)
	local buffer = ""
	for i = 1, #content do
		buffer = buffer .. content:sub(i, i)
		if i % 500 == 0 then
			file:write(buffer)
			buffer = ""
		end
	end
	if buffer ~= "" then
		file:write(buffer)
	end

	file:close()
end

return write_file
