---@alias dev_opts {keywords?: string[], auto?: boolean, ignore_branch?: string|string[], fetch_branch?: boolean }
---@alias behavior
---| 'error' # Raises an error if a kye exists in multiple tables
---| 'keep'  # Uses the value from the leftmost table (first occurrence)
---| 'force' # Uses the value from the rightmost table (last occurrence)

---@class CacheElement
---@field keywords string[]|nil
---@field plugin_path string|nil
---@field require_path string|nil
---@field error boolean|nil
---@field fetch_branch boolean|nil
---@field auto boolean|nil
---@field ignore_branch string|string[]|nil
---@field branch string|nil

---@class Cache
---@type table<string, CacheElement>
