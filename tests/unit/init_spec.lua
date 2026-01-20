local default_config = require("neotest-java.default_config")
local eq = assert.are.same

describe("NeotestJava plugin", function()
	it("should init default configuration", function()
		do
			local adapter = require("neotest-java")
			eq(default_config, adapter.config)
		end

		do
			local adapter = require("neotest-java")({})
			eq(default_config, adapter.config)
		end
	end)

	it("does not throw when adapter is initialized outside of a java project", function()
		--- @type neotest-java.Adapter
		local adapter = require("neotest-java")({}, {
			root_finder = {
				find_root = function()
					return nil
				end,
			},
		})
		eq(nil, adapter.root("some_dir"))
	end)

	it("should respect disable_update_notifications config option", function()
		-- Test that the config option is properly merged
		local adapter_with_notifications = require("neotest-java")({
			disable_update_notifications = false,
		}, {
			root_finder = {
				find_root = function()
					return nil
				end,
			},
		})

		local adapter_without_notifications = require("neotest-java")({
			disable_update_notifications = true,
		}, {
			root_finder = {
				find_root = function()
					return nil
				end,
			},
		})

		-- Both should have the config set correctly
		eq(false, adapter_with_notifications.config.disable_update_notifications)
		eq(true, adapter_without_notifications.config.disable_update_notifications)
	end)
end)
