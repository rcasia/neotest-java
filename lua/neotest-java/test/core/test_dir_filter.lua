local LuaUnit = require 'luaunit'.LuaUnit
local assertEquals = require 'luaunit'.assertEquals

local dir_filter = require 'lua.neotest-java.main.core.dir_filter'

TestDirFilter = {}
  function TestDirFilter:testShouldFilterDir()
    -- given
    local name = 'java'
    local rel_path = 'src/test/java/com/example'
    local root = '/home/user/project/'

    -- when
    local actual = dir_filter:filter_dir(name, rel_path, root)

    -- then
    local expected = true

    assertEquals(actual, expected)
  end

LuaUnit.run()
