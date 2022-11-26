local LuaUnit = require 'luaunit'.LuaUnit
local assertEquals = require 'luaunit'.assertEquals

local adapter = require 'adapter'


TestNeoTestJavaAdapter = {}

  function TestNeoTestJavaAdapter:testShouldFindRoot()
    -- given
    local abspath = '/home/user/project/src/test/java/com/example/MyTest.java'

    -- when
    local actual = adapter.root(abspath)

    -- then
    local expected = '/home/user/project/'

    assertEquals(actual, expected)
  end

  function TestNeoTestJavaAdapter:testShouldFilterDir()
    -- given
    local name = 'java'
    local rel_path = 'src/test/java/com/example'
    local root = '/home/user/project/'

    -- when
    local actual = adapter.filter_dir(name, rel_path, root)

    -- then
    local expected = true

    assertEquals(actual, expected)
  end

LuaUnit.run()
