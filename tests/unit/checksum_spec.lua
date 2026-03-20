local checksum = require("neotest-java.util.checksum")

local eq = require("tests.assertions").eq

describe("Checksum", function()
	describe("sha256", function()
		it("computes checksum for text files", function()
			local tmp_file = vim.fn.tempname()
			local test_content = "Hello, World!\n"

			local f = io.open(tmp_file, "wb")
			f:write(test_content)
			f:close()

			local hash, err = checksum.sha256(tmp_file)
			local hash2, err2 = checksum.sha256(tmp_file)
			os.remove(tmp_file)

			MiniTest.expect.no_error(function()
				assert(err == nil, "Expected no error, got: " .. tostring(err))
				assert(err2 == nil, "Expected no error on second call, got: " .. tostring(err2))
				assert(hash ~= nil, "Expected hash to be computed")
				assert(#hash == 64, "SHA256 hash should be 64 characters")
			end)
		end)

		it("computes checksum for binary files", function()
			local tmp_file = vim.fn.tempname()
			local f = io.open(tmp_file, "wb")
			f:write(string.char(0x00, 0x01, 0x02, 0x03, 0xFF))
			f:close()

			local hash, err = checksum.sha256(tmp_file)
			os.remove(tmp_file)

			MiniTest.expect.no_error(function()
				assert(err == nil, "Expected no error for binary file")
				assert(hash ~= nil, "Expected hash to be computed for binary file")
			end)
		end)

		it("returns error for non-existent file", function()
			local hash, err = checksum.sha256("/non/existent/file/path.txt")

			MiniTest.expect.no_error(function()
				assert(hash == nil, "Expected nil hash for non-existent file")
				assert(err ~= nil, "Expected error for non-existent file")
			end)
		end)

		it("works cross-platform (unix and windows)", function()
			local tmp_file = vim.fn.tempname()
			local f = io.open(tmp_file, "w")
			f:write("test content")
			f:close()

			local hash, err = checksum.sha256(tmp_file)
			os.remove(tmp_file)

			MiniTest.expect.no_error(function()
				assert(err == nil, "Should work with platform-native paths")
				assert(hash ~= nil, "Should compute hash with platform-native paths")
			end)
		end)
	end)
end)
