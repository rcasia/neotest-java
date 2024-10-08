local nio = require("nio")
local compatible_path = require("neotest-java.util.compatible_path")
local Path = require("plenary.path")

---@param filepath string
---@param content string
local function write_file(filepath, content)
	-- for os compatibibility
	local _filepath = compatible_path(filepath)
	-- create parent directories if they don't exist
	nio.fn.mkdir(Path:new(_filepath):parent():absolute(), "p")

	local file = io.open(_filepath, "w") or error("Could not open file for writing: " .. _filepath)
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
