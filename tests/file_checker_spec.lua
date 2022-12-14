local async = require("plenary.async.tests")
local plugin = require("neotest-java")
local Tree = require("neotest.types").Tree

describe("file_checker", function()

  it("should return true for test files", function()
    local test_files = {
      "src/test/java/neotest/NeotestTest.java",
      "src/test/java/neotest/RepositoryTest.java",
    }

    for _, file_path in ipairs(test_files) do
      assert.are.equal(true, plugin.is_test_file(file_path))
    end
  end)


  it("should return false for a non-java file", function()
    local non_test_files = {
      "src/main/java/neotest/Neotest.java",
      "src/main/java/neotest/Repository.java",
    }

    for _, file_path in ipairs(non_test_files) do
      assert.are.equal(false, plugin.is_test_file(file_path))
    end
  end)
end)

