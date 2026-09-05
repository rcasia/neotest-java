local checksum = require("neotest-java.util.checksum")

local eq = require("tests.assertions").eq

describe("Checksum", function()
	describe("sha256", function()
		it("computes checksum for text files", function()
			-- Create a temporary file with known content
			local tmp_file = vim.fn.tempname()
			local test_content = "Hello, World!\n"

			-- Write test content in binary mode to avoid line ending conversion on Windows
			local f = assert(io.open(tmp_file, "wb"), "failed to open temp file")
			f:write(test_content)
			f:close()

			-- Compute checksum
			local hash, err = checksum.sha256(tmp_file)

			-- Recompute to verify consistency
			local hash2, err2 = checksum.sha256(tmp_file)

			-- Clean up
			os.remove(tmp_file)

			-- Verify
			assert(err == nil, "Expected no error, got: " .. tostring(err))
			assert(err2 == nil, "Expected no error on second call, got: " .. tostring(err2))
			assert(hash ~= nil, "Expected hash to be computed")
			eq(64, #hash, "SHA256 hash should be 64 characters (hex)")
			eq(hash, hash2, "Checksum should be consistent")
			-- Verify it's a valid hex string
			local is_hex = hash and hash:match("^[a-f0-9]+$") ~= nil
			assert(is_hex, "Hash should be lowercase hex: " .. hash)
		end)

		it("computes checksum for binary files", function()
			-- Create a temporary binary file
			local tmp_file = vim.fn.tempname()

			-- Write binary data (including null bytes which cause vim.fn.sha256 to fail)
			local f = assert(io.open(tmp_file, "wb"), "failed to open temp file")
			f:write(string.char(0x00, 0x01, 0x02, 0x03, 0x00, 0xFF))
			f:close()

			-- Compute checksum
			local hash, err = checksum.sha256(tmp_file)

			-- Clean up
			os.remove(tmp_file)

			-- Verify
			assert(err == nil, "Expected no error, got: " .. tostring(err))
			assert(hash ~= nil, "Expected hash to be computed")
			eq(64, #hash, "SHA256 hash should be 64 characters (hex)")
		end)

		it("returns error for non-existent file", function()
			local non_existent = "/tmp/this-file-definitely-does-not-exist-" .. os.time() .. ".txt"

			local hash, err = checksum.sha256(non_existent)

			assert(hash == nil, "Expected hash to be nil")
			assert(err ~= nil, "Expected error message")
			assert(err and err:match("Failed to compute checksum") ~= nil, "Error should mention checksum failure")
		end)

		it("works cross-platform (unix and windows)", function()
			-- This test verifies the platform detection logic works
			-- It should succeed on both Unix (using shasum) and Windows (using CertUtil)
			local tmp_file = vim.fn.tempname()
			local test_content = "cross-platform test"

			-- Write test content
			local f = assert(io.open(tmp_file, "w"), "failed to open temp file")
			f:write(test_content)
			f:close()

			-- Compute checksum
			local hash, err = checksum.sha256(tmp_file)

			-- Clean up
			os.remove(tmp_file)

			-- Verify
			assert(err == nil, "Expected no error on current platform, got: " .. tostring(err))
			assert(hash ~= nil, "Expected hash to be computed on current platform")
			eq(64, #hash, "SHA256 hash should be 64 characters (hex)")

			-- Verify it's a valid hex string
			local is_hex = hash and hash:match("^[a-f0-9]+$") ~= nil
			assert(is_hex, "Hash should be lowercase hex: " .. hash)
		end)
	end)
end)
