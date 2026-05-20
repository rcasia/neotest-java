-- Type definitions for external libraries used by neotest-java
-- This file is not loaded at runtime, only used by lua-language-server for type checking

---@class neotest.Position
---@field id string
---@field name string
---@field type "test" | "namespace" | "dir" | "file"
---@field path string
---@field range integer[]

---@class neotest.Tree
---@field data fun(): neotest.Position
---@field iter fun(): fun():integer[], neotest.Position
---@field to_list fun(): neotest.Position[]
---@field children fun(): neotest.Tree[]
---@field root fun(): neotest.Tree

---@class neotest.Error
---@field message string
---@field line integer?

---@class neotest.Result
---@field status neotest.ResultStatus
---@field output string?
---@field short string?
---@field errors neotest.Error[]?

---@alias neotest.ResultStatus "passed" | "failed" | "skipped"

---@class neotest.RunArgs
---@field tree neotest.Tree
---@field strategy string?

---@class neotest.RunSpec
---@field command string|string[]
---@field env table<string, string>?
---@field cwd string?
---@field context table?
---@field strategy table?

---@class neotest.StrategyResult
---@field code integer
---@field output string

---@class neotest.Adapter
---@field name string
---@field root fun(dir: string): string?
---@field is_test_file fun(filepath: string): boolean
---@field discover_positions fun(filepath: string): neotest.Tree
---@field build_spec fun(args: neotest.RunArgs): neotest.RunSpec|neotest.RunSpec[]|nil
---@field results fun(spec: neotest.RunSpec, strategy_result: neotest.StrategyResult): table<string, neotest.Result>
---@field filter_dir fun(name: string): boolean

---@class vim.lsp.Client
---@field name string
---@field initialized boolean
---@field attached_buffers integer[]
---@field request fun(method: string, params: table, callback: fun(err: any, result: any)?, bufnr: integer?)
---@field config table

---@class nio.control.Event
---@field wait fun()
---@field set fun()
