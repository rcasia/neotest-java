local run_sync = require("tests.async_helpers").run_sync
local async = require("tests.async_helpers").async

describe("async_helpers.run_sync", function()
	it("returns the value produced by the wrapped function", function()
		local v = run_sync(function()
			return 42
		end)
		assert.are.same(42, v)
	end)

	it("returns multiple values", function()
		local a, b = run_sync(function()
			return 1, "two"
		end)
		assert.are.same(1, a)
		assert.are.same("two", b)
	end)

	it("forwards arguments to the wrapped function", function()
		local v = run_sync(function(x, y)
			return x + y
		end, 2, 3)
		assert.are.same(5, v)
	end)

	it("re-raises a sync error from the wrapped function", function()
		local ok, err = pcall(run_sync, function()
			error("BOOM")
		end)
		assert.is_false(ok)
		assert.is_not_nil(err:match("BOOM"))
	end)

	it("re-raises a luassert assertion failure from the wrapped function", function()
		local ok, err = pcall(run_sync, function()
			assert.are.same(1, 2)
		end)
		assert.is_false(ok)
		assert.is_not_nil(err:match("Expected objects to be the same"))
	end)
end)

describe("async_helpers.async", function()
	it(
		"runs the wrapped body inside an nio task (no failure)",
		async(function()
			assert.are.same(1, 1)
		end)
	)

	it("returns a function that runs the body via run_sync", function()
		local ran = false
		local wrapped = async(function()
			ran = true
		end)
		assert.is_function(wrapped)
		wrapped()
		assert.is_true(ran)
	end)

	it("propagates errors from the wrapped body when invoked", function()
		local wrapped = async(function()
			error("KABOOM")
		end)
		local ok, err = pcall(wrapped)
		assert.is_false(ok)
		assert.is_not_nil(err:match("KABOOM"))
	end)

	it("propagates assertion failures from the wrapped body when invoked", function()
		local wrapped = async(function()
			assert.are.same(1, 2)
		end)
		local ok, err = pcall(wrapped)
		assert.is_false(ok)
		assert.is_not_nil(err:match("Expected objects to be the same"))
	end)
end)
