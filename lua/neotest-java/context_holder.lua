local log = require("neotest-java.logger")
local nio = require("nio")

---@type neotest-java.ConfigOpts
local default_config = {
	ignore_wrapper = false,
	junit_jar = vim.fn.stdpath("data") .. "/neotest-java/junit-platform-console-standalone-1.10.1.jar",
}

---@type neotest-java.Context
local context = { root = nil, config = default_config }

---@type neotest-java.ContextHolder
return {
	--
	get_context = function()
		return context
	end,
	set_opts = function(opts)
		context.config = vim.tbl_extend("force", context.config, opts)
		log.debug("Config updated: ", context.config)
	end,
	set_root = function(root)
		context.root = root
	end,
}

---@class neotest-java.ConfigOpts
---@field ignore_wrapper boolean
---@field junit_jar string

---@class neotest-java.Context
---@field config neotest-java.ConfigOpts
---@field root string|nil
---
---@class neotest-java.ContextHolder
---@field get_context fun(): neotest-java.Context
---@field set_opts fun(opts: neotest-java.ConfigOpts)
---@field set_root fun(root: string)
