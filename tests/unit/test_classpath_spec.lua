local assertions = require("tests.assertions")
local eq = assertions.eq

local Classpath = require("neotest-java.model.classpath")
local Path = require("neotest-java.model.path")

describe("Classpath", function()
	it("joins entries with the given separator", function()
		eq("a:b:c", Classpath({ "a", "b", "c" }, { separator = ":" }):to_string())
		eq("a;b;c", Classpath({ "a", "b", "c" }, { separator = ";" }):to_string())
	end)

	it("accepts Path entries", function()
		eq("a:b", Classpath({ Path("a"), Path("b") }, { separator = ":" }):to_string())
	end)

	it("stringifies implicitly via tostring", function()
		eq("a:b", tostring(Classpath({ "a", "b" }, { separator = ":" })))
	end)

	it("compares by joined value", function()
		eq(Classpath({ "a", "b" }, { separator = ":" }), Classpath({ "a", "b" }, { separator = ":" }))
		assert(
			Classpath({ "a", "b" }, { separator = ":" }) ~= Classpath({ "a", "b" }, { separator = ";" }),
			"expected different separators to compare unequal"
		)
	end)

	it("reports emptiness", function()
		assert(Classpath(nil, { separator = ":" }):is_empty(), "expected nil entries to be empty")
		assert(Classpath({}, { separator = ":" }):is_empty(), "expected no entries to be empty")
		assert(not Classpath({ "a" }, { separator = ":" }):is_empty(), "expected an entry to be non-empty")
	end)

	it("appends one entry without mutating", function()
		local base = Classpath({ "a" }, { separator = ":" })
		eq("a:b", base:append("b"):to_string())
		eq("a", base:to_string())
	end)

	it("merges two classpaths preserving order", function()
		local merged = Classpath({ "a" }, { separator = ":" }):merge(Classpath({ "b", "c" }))
		eq("a:b:c", merged:to_string())
	end)

	it("preserves duplicates and order exactly", function()
		eq("b:a:b", Classpath({ "b", "a", "b" }, { separator = ":" }):to_string())
	end)
end)
