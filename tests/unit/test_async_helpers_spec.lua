local run_sync = require("tests.async_helpers").run_sync
local async = require("tests.async_helpers").async
local eq = require("tests.assertions").eq

describe("async_helpers.run_sync", function()
	it("returns the value produced by the wrapped function", function()
		local v = run_sync(function()
			return 42
		end)
		eq(42, v)
	end)

	it("returns multiple values", function()
		local a, b = run_sync(function()
			return 1, "two"
		end)
		eq(1, a)
		eq("two", b)
	end)

	it("forwards arguments to the wrapped function", function()
		local v = run_sync(function(x, y)
			return x + y
		end, 2, 3)
		eq(5, v)
	end)

	it("re-raises a sync error from the wrapped function", function()
		local ok, err = pcall(run_sync, function()
			error("BOOM")
		end)
		assert(not ok)
		assert(err:match("BOOM") ~= nil)
	end)

	it("re-raises an assertion failure from the wrapped function", function()
		local ok, err = pcall(run_sync, function()
			eq(1, 2)
		end)
		assert(not ok)
		assert(err:match("tables not equal") ~= nil)
	end)
end)

describe("async_helpers.async", function()
	it(
		"runs the wrapped body inside an nio task (no failure)",
		async(function()
			eq(1, 1)
		end)
	)

	it("returns a function that runs the body via run_sync", function()
		local ran = false
		local wrapped = async(function()
			ran = true
		end)
		assert(type(wrapped) == "function")
		wrapped()
		assert(ran)
	end)

	it("propagates errors from the wrapped body when invoked", function()
		local wrapped = async(function()
			error("KABOOM")
		end)
		local ok, err = pcall(wrapped)
		assert(not ok)
		assert(err:match("KABOOM") ~= nil)
	end)

	it("propagates assertion failures from the wrapped body when invoked", function()
		local wrapped = async(function()
			eq(1, 2)
		end)
		local ok, err = pcall(wrapped)
		assert(not ok)
		assert(err:match("tables not equal") ~= nil)
	end)
end)
