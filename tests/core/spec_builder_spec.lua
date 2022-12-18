local async = require("plenary.async.tests")
local plugin = require("neotest-java")
local Tree = require("neotest.types.tree")

describe("SpecBuilder", function()

  it("builds the spec", function()
    local args = {
      tree = {
        data = function()
          return {
            path = "/home/user/project/src/test/java/com/example/ExampleTest.java",
            name = "test1"
          }
        end
      },
      extra_args = {},
    }
   
    -- when
    local actual = plugin.build_spec(args)

  
    -- then
    local expected_position = "com.example.ExampleTest#test1"

    local expected_command = "mvn test -Dtest=" .. expected_position
    local expected_cwd = "/home/user/project"

    assert.are.equal(expected_command, actual.command)
    assert.are.equal(expected_cwd, actual.cwd)

  end)
end)

