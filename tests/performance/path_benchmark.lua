-- === BENCHMARKING PATH IMPLEMENTATION (N=100000) ===
-- Native (vim.fs + strings)      : 75.85 ms (0.0008 ms/op)
-- Your Path Struct               : 932.97 ms (0.0093 ms/op)
-- Allocation Cost (Path())       : 119.96 ms (0.0012 ms/op)

local Path = require("neotest-java.model.path")

local ITERATIONS = 100000 -- 100k iteraciones es un buen estándar para "hot loops"
local LONG_PATH = "/usr/local/include/node/openssl/archs/linux-x86_64/asm/include/openssl/opensslconf.h"

local function benchmark(name, fn)
	collectgarbage() -- force a cleanup before starting to be fair
	local start = vim.uv.hrtime()

	for _ = 1, ITERATIONS do
		fn()
	end

	local end_time = vim.uv.hrtime()
	local duration_ms = (end_time - start) / 1000000
	print(string.format("%-30s : %.2f ms (%.4f ms/op)", name, duration_ms, duration_ms / ITERATIONS))
end

print(string.format("=== BENCHMARKING PATH IMPLEMENTATION (N=%d) ===", ITERATIONS))

benchmark("Native (vim.fs + strings)", function()
	local parent = vim.fs.dirname(LONG_PATH)
	local joined = parent .. "/" .. "new_file.lua"
	-- simulating basic normalization
	local _ = joined:gsub("\\", "/")
end)

benchmark("Path Struct", function()
	local p = Path(LONG_PATH)
	local parent = p.parent()
	local _ = parent.append("new_file.lua")
end)

benchmark("Allocation Cost (Path())", function()
	local _ = Path(LONG_PATH)
end)
