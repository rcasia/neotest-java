-- === BENCHMARKING PATH IMPLEMENTATION (N=100000) ===
-- Native (vim.fs + strings)      : 83.88 ms (0.0008 ms/op)
-- Path Struct                    : 550.41 ms (0.0055 ms/op)
-- Allocation Cost (Path())       : 10.25 ms (0.0001 ms/op)
-- Plenary Path (Creation)        : 199.67 ms (0.0020 ms/op)
-- Plenary Path (Parent)          : 1843.74 ms (0.0184 ms/op)
--
-- === MEMORY FOOTPRINT ===
-- Path (Allocation)              : 21875.00 KB total (0.2188 KB/op)
-- Plenary Path (Creation)        : 21256.73 KB total (0.2126 KB/op)

local has_plenary, PlenaryPath = pcall(require, "plenary.path")

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

local function benchmark_memory(name, fn)
	collectgarbage()
	local before = collectgarbage("count") -- in KB

	for _ = 1, ITERATIONS do
		fn()
	end

	local after = collectgarbage("count")
	local diff = after - before
	print(string.format("%-30s : %.2f KB total (%.4f KB/op)", name, diff, diff / ITERATIONS))
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
	local parent = p:parent()
	local _ = parent:append("new_file.lua")
end)

benchmark("Allocation Cost (Path())", function()
	local _ = Path(LONG_PATH)
end)

if has_plenary then
	benchmark("Plenary Path (Creation)", function()
		local _ = PlenaryPath:new(LONG_PATH)
	end)

	benchmark("Plenary Path (Parent)", function()
		local p = PlenaryPath:new(LONG_PATH)
		local _ = p:parent()
	end)
else
	print("Skipping Plenary benchmark (plugin not found)")
end

print("\n=== MEMORY FOOTPRINT ===")
benchmark_memory("Path (Allocation)", function()
	local _ = Path(LONG_PATH)
end)

if has_plenary then
	benchmark_memory("Plenary Path (Creation)", function()
		local _ = PlenaryPath:new(LONG_PATH)
	end)
else
	print("Skipping Plenary benchmark (plugin not found)")
end
