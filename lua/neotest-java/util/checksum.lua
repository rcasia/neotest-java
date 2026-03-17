--- Cross-platform SHA256 checksum computation for files
--- Uses external commands to compute checksums reliably across platforms and Neovim versions
--- This avoids issues with vim.fn.sha256() which fails on binary data in some Neovim versions

local M = {}

--- Compute SHA256 checksum for a file
--- @param filepath string The absolute path to the file
--- @return string|nil hash The SHA256 hash, or nil on error
--- @return string|nil error_msg Error message if computation failed
function M.sha256(filepath)
	-- Detect platform
	local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

	local cmd, args
	if is_windows then
		-- Windows: use CertUtil
		cmd = "CertUtil"
		args = { "-hashfile", filepath, "SHA256" }
	else
		-- Unix-like (Linux, macOS): use shasum
		cmd = "shasum"
		args = { "-a", "256", filepath }
	end

	local result = vim.system(vim.list_extend({ cmd }, args)):wait()

	if result.code ~= 0 then
		return nil, "Failed to compute checksum: " .. (result.stderr or "unknown error")
	end

	-- Parse output based on platform
	if is_windows then
		-- CertUtil output format:
		-- SHA256 hash of <filepath>:
		-- <hash>
		-- CertUtil: -hashfile command completed successfully.
		local lines = vim.split(result.stdout, "\n")
		-- Hash is on the second line
		if #lines >= 2 then
			local hash = lines[2]:gsub("%s+", ""):lower()
			return hash, nil
		else
			return nil, "Failed to parse CertUtil output"
		end
	else
		-- shasum output format: "hash  filename\n"
		-- Extract just the hash part
		local hash = vim.split(result.stdout, "%s+")[1]
		return hash, nil
	end
end

return M
