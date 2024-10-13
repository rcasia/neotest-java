local nio = require("nio")
local compatible_path = require("neotest-java.util.compatible_path")
local Path = require("plenary.path")
local logger = require("neotest-java.logger")

local BUFFER_SIZE = 500

---@param filepath string
---@param content string
local function write_file(filepath, content)
	-- for os compatibibility
	local _filepath = compatible_path(filepath)
	-- create parent directories if they don't exist
	nio.fn.mkdir(Path:new(_filepath):parent():absolute(), "p")

	logger.debug("writing to file: ", _filepath)

	local file = io.open(_filepath, "w") or error("Could not open file for writing: " .. _filepath)
	local pointer = 1
	for i = BUFFER_SIZE, #content, BUFFER_SIZE do
		file:write(content:sub(pointer, i))
		pointer = i + 1
	end
	if pointer <= #content then
		file:write(content:sub(pointer))
	end

	file:close()
end

return write_file
