local checksum = require("neotest-java.util.checksum")

local eq = require("tests.assertions").eq

describe("Checksum", function()
	describe("sha256", function()
		it("computes checksum for text files", function()
			-- Create a temporary file with known content
			local tmp_file = vim.fn.tempname()
			local test_content = "Hello, World!\n"
			local expected_hash = "c98c24b677eff44860afea6f493bbaec5bb1c4cbb209c6fc2bbb47f66ff2ad31"

			-- Write test content
			local f = io.open(tmp_file, "w")
			f:write(test_content)
			f:close()

			-- Compute checksum
			local hash, err = checksum.sha256(tmp_file)

			-- Clean up
			os.remove(tmp_file)

			-- Verify
			assert.is_nil(err, "Expected no error, got: " .. tostring(err))
			eq(expected_hash, hash)
		end)

		it("computes checksum for binary files", function()
			-- Create a temporary binary file
			local tmp_file = vim.fn.tempname()

			-- Write binary data (including null bytes which cause vim.fn.sha256 to fail)
			local f = io.open(tmp_file, "wb")
			f:write(string.char(0x00, 0x01, 0x02, 0x03, 0x00, 0xFF))
			f:close()

			-- Compute checksum
			local hash, err = checksum.sha256(tmp_file)

			-- Clean up
			os.remove(tmp_file)

			-- Verify
			assert.is_nil(err, "Expected no error, got: " .. tostring(err))
			assert.is_not_nil(hash, "Expected hash to be computed")
			eq(64, #hash, "SHA256 hash should be 64 characters (hex)")
		end)

		it("returns error for non-existent file", function()
			local non_existent = "/tmp/this-file-definitely-does-not-exist-" .. os.time() .. ".txt"

			local hash, err = checksum.sha256(non_existent)

			assert.is_nil(hash, "Expected hash to be nil")
			assert.is_not_nil(err, "Expected error message")
			assert.is_true(err:match("Failed to compute checksum") ~= nil, "Error should mention checksum failure")
		end)

		it("works cross-platform (unix and windows)", function()
			-- This test verifies the platform detection logic works
			-- It should succeed on both Unix (using shasum) and Windows (using CertUtil)
			local tmp_file = vim.fn.tempname()
			local test_content = "cross-platform test"

			-- Write test content
			local f = io.open(tmp_file, "w")
			f:write(test_content)
			f:close()

			-- Compute checksum
			local hash, err = checksum.sha256(tmp_file)

			-- Clean up
			os.remove(tmp_file)

			-- Verify
			assert.is_nil(err, "Expected no error on current platform, got: " .. tostring(err))
			assert.is_not_nil(hash, "Expected hash to be computed on current platform")
			eq(64, #hash, "SHA256 hash should be 64 characters (hex)")

			-- Verify it's a valid hex string
			local is_hex = hash:match("^[a-f0-9]+$") ~= nil
			assert.is_true(is_hex, "Hash should be lowercase hex: " .. hash)
		end)
	end)
end)
