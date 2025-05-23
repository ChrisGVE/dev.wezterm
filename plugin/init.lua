local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm

local M = {}

local is_windows = wezterm.target_triple:find("windows")
local separator = is_windows and "\\" or "/"

local utils = nil

M.bootstrap = true

---@type CacheElement
local default_element = {
	keywords = {},
	plugin_path = nil,
	require_path = nil,
	error = false,
	fetch_branch = false,
	branch = nil,
	auto = true,
	ignore_branch = { "main", "master" },
}

---@type Cache
M.cache = {}

-- Centralized error handler for consistent error management
---@param error_type string
---@param message string
---@param should_throw boolean
local function handle_error(error_type, message, should_throw)
	wezterm.log_error("dev.wezterm: " .. message)
	wezterm.emit("dev.wezterm." .. error_type, message)
	if should_throw then
		error(message)
	end
end

-- check if `str` is included in `array`
---@param str string
---@param array string|string[]
---@return boolean
function string.is_in(str, array)
	if type(array) == "string" and str:lower() == array:lower() then
		return true
	elseif type(array) == "table" then
		for _, v in ipairs(array) do
			if v:lower() == str:lower() then
				return true
			end
		end
	end
	return false
end

---@param hashkey string
---@return CacheElement|nil
local function get_cache_element_from_hash(hashkey)
	if hashkey and M.cache[hashkey] then
		return M.cache[hashkey]
	else
		return handle_error("invalid_hashkey", "Invalid hashkey: " .. (hashkey or "nil"), false)
	end
end

---@param cache_element CacheElement
---@return string|nil plugin_path
---@return string|nil require_path
local function search_path(cache_element)
	local keywords = cache_element.keywords
	if keywords and type(keywords) == "string" then
		cache_element.keywords = { keywords }
	end
	-- iterate through every installed plugin
	for _, plugin in ipairs(wezterm.plugin.list()) do
		local found = true
		local decoded_component = ""
		if utils then
			decoded_component = utils.decode_wezterm_dir(plugin.component)
		end
		-- Check the presence of every keywords
		for _, keyword in ipairs(cache_element.keywords) do
			found = found and (decoded_component:find(keyword) ~= nil or plugin.component:find(keyword) ~= nil)
		end
		if found then
			cache_element.plugin_path = plugin.plugin_dir
			cache_element.require_path = plugin.plugin_dir .. separator .. "plugin" .. separator .. "?.lua"
			if M.bootstrap then
				return cache_element.require_path
			elseif cache_element.auto then
				return cache_element.plugin_path, cache_element.require_path
			else
				return
			end
		end
	end
	handle_error("plugin_not_found", "Could not find plugin directory", false)
	if cache_element then
		cache_element.error = true
	end
end

---@param hashkey string
---@return string|nil plugin_path
function M.get_plugin_path(hashkey)
	local cache_element = get_cache_element_from_hash(hashkey)
	if cache_element == nil or cache_element and cache_element.error then
		return nil
	else
		return cache_element.plugin_path
	end
end

---@param hashkey string
---@return string|nil require_path
function M.get_require_path(hashkey)
	local cache_element = get_cache_element_from_hash(hashkey)
	if cache_element == nil or cache_element and cache_element.error then
		return nil
	else
		return cache_element.require_path
	end
end

-- Set the wezterm require path for the plugin
local function _set_wezterm_require_path(path)
	package.path = package.path .. ";" .. path
end

-- Set the wezterm require path for the plugin
---@param hashkey string
function M.set_wezterm_require_path(hashkey)
	local cache_element = get_cache_element_from_hash(hashkey)
	if cache_element and cache_element.require_path and not cache_element.error then
		_set_wezterm_require_path(cache_element.require_path)
		return
	else
		handle_error("require_path_not_set", "Invalid path", false)
	end
end

---@param opts dev_opts
---@return string|nil hashkey
---@return string|nil plugin_path
local function _setup(opts)
	local hashkey
	local plugin_path
	local require_path

	if opts.auto then
		plugin_path, require_path = search_path(opts)
	else
		hashkey = utils.array_hash(opts.keywords)
		M.cache[hashkey] = opts
		plugin_path, require_path = search_path(opts)
	end

	if opts.auto then
		if require_path then
			_set_wezterm_require_path(require_path)
		end
		return plugin_path
	else
		return hashkey
	end
end

---@param url string
---@param opts dev_opts
---@return any?
function M.require(url, opts)
	local plugin = wezterm.plugin.require(url)
	if plugin == nil then
		return nil
	end
	opts = utils.tbl_deep_extend("force", default_element, opts or {})
	return plugin, _setup(opts)
end

---@param opts dev_opts
---@return string|nil hashkey
---@return string|nil plugin_path
function M.setup(opts)
	if not opts then
		return handle_error("invalid_opts", "Options table is required", false)
	end

	if not opts.keywords or (type(opts.keywords) == "table" and #opts.keywords == 0) then
		return handle_error("no_keywords", "No keywords provided", false)
	end

	opts = utils.tbl_deep_extend("force", default_element, opts or {})

	return _setup(opts)
end

local function init()
	---@type CacheElement
	local cache_element = {
		keywords = { "https", "chrisgve", "dev", "wezterm" },
		fetch_branch = false,
		ignore_branch = { "main" },
	}
	_set_wezterm_require_path(search_path(cache_element))
	M.bootstrap = false
	utils = require("utils.utils")
end

init()

return M
