local LuaUnit = require 'luaunit'.LuaUnit
local assertEquals = require 'luaunit'.assertEquals

local adapter = require 'lua.neotest-java.main.adapter'


TestNeoTestJavaAdapter = {}
  function TestNeoTestJavaAdapter:testItExists()
    -- given
    local expected = true

    -- when
    local actual = adapter ~= nil

    -- then
    assertEquals(actual, expected)
  end

LuaUnit.run()
