--- @param path string
--- @return boolean
local function there_is_wrapper_in(path)
	local gradle_wrapper = path .. "/gradlew"
	local maven_wrapper = path .. "/mvnw"
	return vim.fn.filereadable(gradle_wrapper) == 1 or vim.fn.filereadable(maven_wrapper) == 1
end

return there_is_wrapper_in
