local log = require("neotest-java.logger")
local Path = require("neotest-java.model.path")

---@type neotest-java.Context
local context = { root = nil, config = require("neotest-java.default_config") }

---@class neotest-java.ContextHolder
return {
	--
	get_context = function()
		return context
	end,
	config = function()
		return context.config
	end,
	--- @param opts neotest-java.ConfigOpts
	set_opts = function(opts)
		context.config = vim.tbl_extend("force", context.config, opts)
		if type(context.config.junit_jar) == "string" then
			context.config.junit_jar = Path(context.config.junit_jar)
		end
		log.debug("Config updated: ", context.config)
	end,
	set_root = function(root)
		context.root = root
	end,
}

---@class neotest-java.ConfigOpts
---@field junit_jar neotest-java.Path
---@field jvm_args string[]
---@field incremental_build boolean
---@field default_version string
---@field test_classname_patterns string[] | nil

---@class neotest-java.Context
---@field config neotest-java.ConfigOpts
---@field root string|nil
