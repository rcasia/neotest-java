local LuaUnit = require 'luaunit'.LuaUnit
local assertEquals = require 'luaunit'.assertEquals

local root_finder = require 'lua.neotest-java.main.core.root_finder'

TestRootFinder = {}

  function TestRootFinder:testShouldFindRoot()
    -- given
    local abspath = '/home/user/project/src/test/java/com/example/MyTest.java'

    -- when
    local actual = root_finder.findRoot(abspath)

    -- then
    local expected = '/home/user/project/'

    assertEquals(actual, expected)
  end

LuaUnit.run()
