local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm

local M = {}

local is_windows = wezterm.target_triple:find("windows")
local separator = is_windows and "\\" or "/"

local utils = nil

M.substitutions = nil

M.bootstrap = true
M.utils = false

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

---@type CacheElement
M.dev_cache_element = {
	keywords = { "https", "chrisgve", "dev", "wezterm" },
	fetch_branch = true,
	ignore_branch = { "main" },
}

---@type Cache
M.cache = {}

-- Centralized error handler for consistent error management
---@param error_type string
---@param message string
---@param should_throw boolean
local function handle_error(error_type, message, should_throw)
	if error_type == "INFO" then
		wezterm.log_info("dev.wezterm: " .. message)
	elseif error_type == "WARN" or error_type == "WARNING" then
		wezterm.log_warn("dev.wezterm: " .. message)
	elseif error_type == "ERROR" then
		wezterm.log_error("dev.wezterm: " .. message)
	else
		wezterm.log_error("dev.wezterm: " .. message)
		wezterm.emit("dev.wezterm." .. error_type, message)
	end
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
---@param silent? bool
---@return string|nil plugin_path
---@return string|nil require_path
local function search_path(cache_element, silent)
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
			cache_element.error = false
			if M.bootstrap then
				return cache_element.require_path
			elseif cache_element.auto then
				return cache_element.plugin_path, cache_element.require_path
			else
				return
			end
		end
	end
	if not silent then
		handle_error("plugin_not_found", "Could not find plugin directory", false)
	end
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

---@param initial_list string[]
---@return string[]
local function subst(initial_list)
	if M.substitutions then
		local substituted_keywords = {}
		for _, keyword in ipairs(initial_list) do
			local kwd = M.substitutions[keyword]
			if kwd then
				table.insert(substituted_keywords, kwd)
			else
				table.insert(substituted_keywords, keyword)
			end
		end
		return substituted_keywords
	else
		return initial_list
	end
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

	if M.substitutions then
		handle_error("INFO", "Keywords before substitution: " .. table.concat(opts.keywords, ", "), false)
		opts.keywords = subst(opts.keywords)
		handle_error("INFO", "Keywords after substitution: " .. table.concat(opts.keywords, ", "), false)
	end

	opts = utils.tbl_deep_extend("force", default_element, opts or {})

	return _setup(opts)
end

---@param substitute_dict Substitute
function M.set_substitutions(substitute_dict)
	M.substitutions = substitute_dict
	M.dev_cache_element.keywords = subst(M.dev_cache_element.keywords)
	if not M.utils then
		local require_path = search_path(M.dev_cache_element)
		if require_path then
			handle_error("INFO", "set_substitutions: dev.wezterm path found", false)
		end
		_set_wezterm_require_path(require_path)
		M.bootstrap = false
		utils = require("utils.utils")
		M.utils = true
	end
end

local function init()
	local require_path = search_path(M.dev_cache_element, true) -- the first search for dev.wezterm is silent
	if require_path then
		handle_error("INFO", "init: dev.wezterm plugin path found", false)
		_set_wezterm_require_path(require_path)
		M.bootstrap = false
		utils = require("utils.utils")
		M.utils = true
	else
		handle_error("WARN", "init: dev.wezterm plugin path not found", false)
	end
end

init()

return M
