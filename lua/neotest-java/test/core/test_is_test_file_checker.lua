
local LuaUnit = require 'luaunit'.LuaUnit
local assertEquals = require 'luaunit'.assertEquals

local IsTestFileChecker = require 'lua.neotest-java.main.core.is_test_file_checker'

TestRootFinder = {}

    function TestRootFinder.test_is_test_file_checker()
      -- given
      -- list of test filenames
      local test_filenames = {
      'Test.java',
      'CatControllerTest.java',
      'CartRepositoryTest.java',
      }

      for _, test_filename in ipairs(test_filenames) do
        -- when
        local is_test_file = IsTestFileChecker.isTestFile(test_filename)

        -- then
        assertEquals(is_test_file, true)
      end
    end

LuaUnit.run()
