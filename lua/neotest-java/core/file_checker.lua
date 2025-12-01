local JAVA_TEST_FILE_PATTERNS = require("neotest-java.types.patterns").JAVA_TEST_FILE_PATTERNS
local root_finder = require("neotest-java.core.root_finder")
local compatible_path = require("neotest-java.util.compatible_path")
local ch = require("neotest-java.context_holder")
local path = require("plenary.path")

local FileChecker = {}

local matcher = function(pattern)
  return function(dir)
    return string.find(dir, pattern)
  end
end

---@async
---@param file_path string
---@return boolean
function FileChecker.is_test_file(file_path)
  file_path = compatible_path(file_path)

  local root = compatible_path(ch.get_context().root or root_finder.find_root(vim.fn.getcwd(), matcher) or "")

  local relative_path = path:new(file_path):make_relative(root)
  if string.find(relative_path, "/main/") then
    return false
  end
  for _, pattern in ipairs(JAVA_TEST_FILE_PATTERNS) do
    if string.find(relative_path, pattern) then
      return true
    end
  end
  return false
end

return FileChecker
