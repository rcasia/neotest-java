local eq = require("tests.assertions").eq

describe("Invocation-owned reports", function()
	it("isolates rapid runs, rejects stale XML and removes only owned reports", function()
		-- The native mini.test harness intentionally disables nio.scheduler.
		-- Use an unpatched child loop for real async file I/O and Vim functions.
		local code = [[
local root_dir = vim.uv.cwd()
for _, path in ipairs({ root_dir, root_dir .. '/.dependencies/nvim-nio', root_dir .. '/.dependencies/neotest', root_dir .. '/.dependencies/plenary.nvim' }) do
  vim.opt.rtp:append(path)
end
local nio = require('nio')
local Path = require('neotest-java.model.path')
local Tree = require('neotest.types').Tree
local root = Path(vim.fn.tempname())
local XML = '<testsuite><testcase name="selected()" classname="example.Test" time="0"/></testsuite>'
vim.fn.mkdir(tostring(root:append('src/test/java/example')), 'p')
vim.fn.writefile({ '<project><artifactId>fixture</artifactId></project>' }, tostring(root:append('pom.xml')))
local stale = root:append('target/junit-reports/stale')
vim.fn.mkdir(tostring(stale), 'p')
vim.fn.writefile({ XML }, tostring(stale:append('TEST-old.xml')))
local id = 'example.Test#selected()'
local tree = Tree.from_list({ id = id, name = 'selected', type = 'test', path = tostring(root:append('src/test/java/example/Test.java')) }, function(pos) return pos.id end)
tree:data().ref = function() return id end
local adapter = require('neotest-java')({ disable_update_notifications = true }, {
  root_finder = { find_root = function() return tostring(root) end },
  check_junit_jar_deps = { file_exists = function() return true end },
  lsp_compiler = { compile = function() return true end },
  binaries = { java = function() return Path('java') end },
  classpath_provider = { get_classpath = function() return 'classes' end },
})
local done, ok, err
nio.run(function()
  local first = adapter.build_spec({ tree = tree })
  local second = adapter.build_spec({ tree = tree })
  assert(first.context.reports_dir ~= second.context.reports_dir, 'same-second runs must not share reports')
  nio.fn.writefile({ XML }, tostring(first.context.reports_dir:append('TEST-current.xml')))
  local result = adapter.results(first, { code = 0, output = 'process.log' }, tree)
  assert(result[id].status == 'passed', vim.inspect(result))
  local missing = adapter.results(second, { code = 0, output = 'process.log' }, tree)
  assert(missing[id].status == 'failed', vim.inspect(missing))
  assert(missing[id].short:find('No JUnit result', 1, true))
  assert(not vim.uv.fs_stat(tostring(first.context.reports_dir)))
  assert(not vim.uv.fs_stat(tostring(second.context.reports_dir)))
  assert(vim.uv.fs_stat(tostring(stale:append('TEST-old.xml'))))
end, function(success, message)
  ok, err, done = success, message, true
end)
local settled = vim.wait(8000, function() return done end, 10)
vim.fn.delete(tostring(root), 'rf')
if not settled or not ok then
  print(tostring(err or 'report lifecycle timed out'))
  vim.cmd('cquit 1')
else
  vim.cmd('qa!')
end
]]
		local result = vim.system({ vim.v.progpath, "--headless", "-u", "NONE", "-c", "lua " .. code }):wait(10000)
		eq(0, result.code, result.stderr .. result.stdout)
	end)
end)
