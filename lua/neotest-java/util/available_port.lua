local uv = vim.uv
local log = require("neotest-java.logger")

---@param start_port? number
---@param end_port? number
---@return number port
local available_port = function(start_port, end_port)
	start_port = start_port or 5005
	end_port = end_port or 65535

	local function is_port_in_use(port)
		local server = assert(uv.new_tcp())
		local success, err = server:bind("127.0.0.1", port)
		server:close()
		return err ~= nil
	end

	for port = start_port, end_port do
		if not is_port_in_use(port) then
			return port
		end
		log.debug("port: ", port, " is in use")
	end

	error(("No free port found in the specified range [%s - %s]"):format(start_port, end_port))
end

return available_port
