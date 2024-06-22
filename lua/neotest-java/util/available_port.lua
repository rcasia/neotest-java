---@param start_port? number
---@param end_port? number
---@return number port
local available_port = function(start_port, end_port)
	start_port = start_port or 5005
	end_port = end_port or 65535

	local function is_port_in_use(port)
		local handle = assert(io.popen("netstat -an | grep ':" .. port .. "'"))
		local result = handle:read("*a")
		handle:close()
		return result ~= ""
	end

	for port = start_port, end_port do
		if not is_port_in_use(port) then
			return port
		end
	end

	error(("No free port found in the specified range [%s - %s]"):format(start_port, end_port))
end

return available_port
