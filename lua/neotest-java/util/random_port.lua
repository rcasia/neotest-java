local uv = vim.uv

---@return number port
local random_port = function()
	local server = assert(uv.new_tcp())
	assert(server:bind("127.0.0.1", 0))
	local port = server:getsockname().port
	server:close()
	return port
end

return random_port
