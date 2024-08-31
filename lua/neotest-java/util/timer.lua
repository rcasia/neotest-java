---@class neotest-java.Timer
---@field startTime number
---@field endTime number
local Timer = {}
Timer.__index = Timer

-- Method to stop the timer and return the elapsed time
function Timer:stop()
	if self.startTime then
		self.endTime = os.clock() * 1000
		return math.ceil(self.endTime - self.startTime)
	else
		return nil, "Error: The timer has not been started."
	end
end

-- Method to get the elapsed time without stopping the timer
function Timer:getElapsedTime()
	if self.startTime then
		if self.endTime then
			return self.endTime - self.startTime
		else
			return math.ceil((os.clock() * 1000) - self.startTime)
		end
	else
		return nil, "Error: The timer has not been started."
	end
end

-- Method to create and start a new timer
function Timer:start()
	local instance = setmetatable({}, Timer)
	instance.startTime = os.clock() * 1000
	instance.endTime = nil
	return instance
end

---@type neotest-java.Timer
return Timer
