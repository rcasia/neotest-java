local Path = require("plenary.path")
local nio = require("nio")

---@param filepath string
---@param content string
local function write_file(filepath, content)
	-- for os compatibibility
	local _filepath = Path:new(filepath)
	-- create parent directories if they don't exist
	nio.fn.mkdir(_filepath:parent():absolute(), "p")

	local compatible_path = _filepath:absolute()

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
