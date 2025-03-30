local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm

local M = {}

local is_windows = wezterm.target_triple:find("windows")
local separator = is_windows and "\\" or "/"

local utils = {}

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

-- check if `str` is included in `array`
---@param str string
---@param array string|string[]
---@return boolean
function string.is_in(str, array)
	if type(array) == "string" and str == array then
		return true
	elseif type(array) == "table" then
		for _, v in ipairs(array) do
			if v == str then
				return true
			end
		end
	end
	return false
end

---@param path string
---@param branch string
---@return boolean success
---@return string|nil error
local function fetch_branch(path, branch)
	-- Function to run git commands with proper path
	local function runGit(...)
		local cmd = string.format("cd %q && git %s", path, table.concat({ ... }, " "))
		local handle = assert(io.popen(cmd .. " 2>&1"))
		local output = assert(handle:read("*a"))
		local _, _, code = assert(handle:close())

		if code ~= 0 then
			error(output)
		end
		return output
	end

	local success, err = pcall(function()
		-- Check if branch exists in remote
		local output = runGit("ls-remote", "--heads", "origin", branch)
		if output == "" then
			error("Remote branch '" .. branch .. "' does not exist")
		end

		-- Fetch the latest changes
		runGit("fetch", "origin", branch)

		-- Check current branch
		local currentBranch = runGit("rev-parse", "--abbrev-ref", "HEAD"):match("^(.-)%s*$")

		if currentBranch ~= branch then
			-- Checkout the branch
			runGit("checkout", branch)
		else
			-- Pull updates if we're already on the branch
			runGit("pull", "origin", branch)
		end
	end)

	return success, err
end

---@param hashkey string
---@return CacheElement|nil
local function get_cache_element_from_hash(hashkey)
	if hashkey and M.cache[hashkey] then
		return M.cache[hashkey]
	else
		wezterm.log_error("dev.wezterm: invalid hashkey:" .. (hashkey or "nil"))
		wezterm.emit("dev.wezterm.invalid_hashkey")
		return nil
	end
end

---@param hashkey string|nil
---@param opts dev_opts
---@return string|nil plugin_path
---@return string|nil require_path
local function search_path(hashkey, opts)
	local cache_element = nil
	if M.bootstrap then
		local keywords = opts.keywords
		if keywords and type(keywords) == "string" then
			opts.keywords = { keywords }
		end
		cache_element = opts
	elseif hashkey and not opts.auto then
		cache_element = get_cache_element_from_hash(hashkey)
		if cache_element == nil then
			return
		end
	else
		cache_element = utils.deepcopy(default_element)
	end
	if cache_element.keywords then
		-- iterate through every installed plugin
		for _, plugin in ipairs(wezterm.plugin.list()) do
			local found = true
			-- Check the presence of every keywords
			for _, keyword in ipairs(cache_element.keywords) do
				found = found and plugin.component:find(keyword) ~= nil
			end
			if found then
				cache_element.plugin_path = plugin.plugin_dir
				cache_element.branch = plugin.plugin_dir:match("#(.*)$")
				if
					cache_element.branch
					and cache_element.fetch_branch
					and (
						cache_element.ignore_branch and not cache_element.branch:is_in(cache_element.ignore_branch)
						or true
					)
				then
					local success, err = fetch_branch(cache_element.plugin_path, cache_element.branch)
					if not success then
						wezterm.log_error("dev.wezterm: ", err)
						wezterm.emit("dev.wezterm.error_fetching_branch", err)
					end
				end
				cache_element.require_path = plugin.plugin_dir .. separator .. "plugin" .. separator .. "?.lua"
				if M.bootstrap then
					return cache_element.require_path
				elseif opts and opts.auto then
					return cache_element.plugin_path, cache_element.require_path
				else
					cache_element.plugin_path = plugin.plugin_dir
					return
				end
			end
		end
		wezterm.log_error("dev.wezterm: Could not find plugin directory")
		wezterm.emit("dev.wezterm.dir_not_found")
		if cache_element then
			cache_element.error = true
		end
	end
end

---@param hashkey string
---@return string|nil plugin_path
function M.get_plugin_path(hashkey)
	local cache_element = M.cache[hashkey]
	if cache_element == nil or cache_element and cache_element.error then
		return nil
	else
		return cache_element.plugin_path
	end
end

---@param hashkey string
---@return string|nil require_path
function M.get_require_path(hashkey)
	local cache_element = M.cache[hashkey]
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
	if cache_element and cache_element.require_path then
		_set_wezterm_require_path(cache_element.require_path)
		return
	else
		wezterm.emit("dev.wezterm.require_path_not_set", "Invalid path")
	end
end

---@param opts dev_opts
---@return string|nil hashkey
---@return string|nil plugin_path
function M.setup(opts)
	if opts.keywords == nil or #opts.keywords == 0 then
		wezterm.log_error("No keywords provided")
		wezterm.emit("dev.wezterm.no_keywords")
		return nil, nil
	end

	opts = utils.tbl_deep_extend("force", default_element, opts or {})

	local hashkey
	local plugin_path
	local require_path

	if opts.auto then
		plugin_path, require_path = search_path(nil, opts)
	else
		hashkey = utils.array_hash(opts.keywords)
		M.cache[hashkey] = opts
		plugin_path, require_path = search_path(hashkey, opts)
	end

	if opts.auto then
		print(require_path)
		_set_wezterm_require_path(require_path)
		return plugin_path
	else
		return hashkey
	end
end

local function init()
	---@type dev_opts
	local opts = {
		keywords = { "http", "chrisgve", "dev", "wezterm" },
		fetch_branch = true,
		ignore_branch = { "main" },
	}
	_set_wezterm_require_path(search_path(nil, opts))
	M.bootstrap = false
	utils = require("utils.utils")
end

init()

return M
