local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm

local M = {}

local is_windows = wezterm.target_triple:find("windows")
local separator = is_windows and "\\" or "/"

local utils

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
}

---@type Cache
M.cache = {}

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

---@param hashkey? string
---@param keywords? string[]
---@param opts? dev_opts
---@return string|nil require_path
local function search_path(hashkey, keywords, opts)
	local kwds = {}
	local branch = ""
	local plugin_path = ""
	local require_path = ""
	local fetch_branch_flg = false
	local cache_element = nil
	if M.bootstrap and keywords then
		kwds = keywords
		fetch_branch_flg = true -- when in bootstrap mode always look for the branch version if there is one
	elseif keywords and hashkey == nil then
		kwds = keywords
		if opts and opts.fetch_branch then
			fetch_branch_flg = true
		end
	elseif hashkey then
		cache_element = get_cache_element_from_hash(hashkey)
		if cache_element == nil then
			return
		end
		kwds = cache_element.keywords
		fetch_branch_flg = cache_element.fetch_branch
	end
	if kwds then
		-- iterate through every installed plugin
		for _, plugin in ipairs(wezterm.plugin.list()) do
			local found = true
			-- Check the presence of every keywords
			for _, keyword in ipairs(kwds) do
				found = found and plugin.component:find(keyword) ~= nil
			end
			if found then
				plugin_path = plugin.plugin_dir
				branch = plugin.plugin_dir:match("#(.*)$")
				if branch and fetch_branch_flg then
					local success, err = fetch_branch(plugin_path, branch)
					if not success then
						wezterm.log_error("dev.wezterm: ", err)
						wezterm.emit("dev.wezterm.error_fetching_branch", err)
					end
				end
				require_path = plugin.plugin_dir .. separator .. "plugin" .. separator .. "?.lua"
				if M.bootstrap or opts and opts.auto then
					return require_path
				else
					cache_element.plugin_path = plugin.plugin_dir
					cache_element.require_path = require_path
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

---@param keywords string[]|string
---@param opts? table
---@return string|nil hashkey
---@return string|nil plugin_path
function M.setup(keywords, opts)
	if M.bootstrap then
		_set_wezterm_require_path(search_path(nil, { "http", "chrisgve", "dev", "wezterm" }))
		M.bootstrap = false
	end

	utils = require("utils.utils")

	if keywords == nil or #keywords == 0 then
		wezterm.log_error("No keywords provided")
		wezterm.emit("dev.wezterm.no_keywords")
		return nil, nil
	end

	---@type string[]
	local keywords_table
	if type(keywords) == "string" then
		keywords_table = { keywords }
	else
		keywords_table = keywords
	end

	local hashkey = utils.array_hash(keywords_table)
	local plugin_path, require_path = search_path(hashkey, keywords_table, opts)

	if opts and opts.auto then
		_set_wezterm_require_path(require_path)
		return nil, plugin_path
	else
		M.cache[hashkey] = utils.deepcopy(default_element)
		local cache_element = M.cache[hashkey]
		cache_element.keywords = keywords_table
		cache_element.auto = false
		if opts then
			cache_element.fetch_branch = opts.fetch_branch or false
		end
		cache_element.plugin_path = plugin_path
		cache_element.require_path = require_path
		return hashkey, nil
	end
end

return M
