-- Helpers for running async (nio) code from inside plain `it(...)` blocks.
--
-- Why this exists
-- ---------------
-- mini.test schedules its "I'm done, quit Neovim" callback on `vim.schedule`.
-- nio's own `nio.tests` (`async.it`) wraps each test in an outer task and
-- spins on `vim.wait(..., fast_only = true)` to keep mini.test's quitter from
-- stealing the process before the test finishes.
--
-- Outside of `async.it`, we cannot block the calling coroutine on an nio task
-- without re-introducing the same race. `run_sync` is the small primitive
-- that lets a synchronous `it(...)` body launch an nio task and
--   * receive its return values, or
--   * re-raise its error
-- so failures are visible as proper test failures (not as silent timeouts).
--
-- Caveat: the wait uses `fast_only = true` (same as the `nio.tests` patch in
-- `scripts/minimal_init.lua`). Anything that resumes via `vim.schedule`
-- (notably `nio.sleep`, `nio.scheduler`, or `vim.defer_fn` callbacks) will
-- NOT progress while we wait. This helper is therefore safe for tests that
-- merely need an async-capable context (e.g. to call nio-wrapped functions
-- like `nio.fn.tempname` or to construct objects whose constructor calls
-- nio APIs that don't actually yield), but it is NOT a substitute for
-- `async.it` when the code under test really sleeps or yields.

local M = {}

local nio = require("nio")

--- Run `fn(...)` inside an nio task and block until it completes.
--- Returns whatever `fn` returned, or re-raises whatever `fn` raised.
---
--- @param fn fun(...): ... function to run inside an nio task
--- @param ... any forwarded to `fn`
--- @return ... the values returned by `fn`
function M.run_sync(fn, ...)
	local args = { ... }
	local done, ok, value
	nio.run(function()
		return fn(unpack(args))
	end, function(success, ...)
		ok = success
		if success then
			value = { ... }
		else
			value = (...)
		end
		done = true
	end)

	local timeout = tonumber(vim.env.NIO_RUN_SYNC_TIMEOUT) or 5000
	-- fast_only = true: do NOT process vim.schedule callbacks while waiting,
	-- otherwise mini.test's reporter will cquit the process mid-test (see
	-- the nio.tests patch in scripts/minimal_init.lua for context).
	local completed = vim.wait(timeout, function()
		return done == true
	end, 5, true)

	if not completed then
		error(string.format("run_sync: task did not complete within %dms", timeout), 2)
	end

	if not ok then
		error(value, 2)
	end

	return unpack(value or {})
end

--- Wrap a test body so that it runs inside an nio task.
---
--- Usage:
---     it("does the thing", async(function()
---         local result = some_nio_call()
---         eq(expected, result)
---     end))
---
--- Equivalent to writing `function() run_sync(fn) end` by hand, but reads as
--- a direct replacement for `async.it("...", function() ... end)` while still
--- producing real failures (assertion errors and `error()` calls re-raise out
--- of `run_sync` as proper test failures).
---
--- Same caveats as `run_sync`: the body must not actually yield (no
--- `nio.sleep`, `nio.scheduler`, etc.). For genuinely yielding code keep
--- using `nio.tests.it`.
---
--- @param fn fun(...): ... test body to run inside an nio task
--- @return fun() a function suitable to pass as the second arg to `it(...)`
function M.async(fn)
	return function()
		M.run_sync(fn)
	end
end

return M
