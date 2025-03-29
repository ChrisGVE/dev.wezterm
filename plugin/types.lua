---@alias dev_opts {fetch_branch: boolean?, auto: boolean?}

---@class CacheElement
---@field keywords string[]|nil
---@field plugin_path string|nil
---@field require_path string|nil
---@field error boolean|nil
---@field fetch_branch boolean|nil
---@field auto boolean|nil

---@class Cache
---@type table<string, CacheElement>
