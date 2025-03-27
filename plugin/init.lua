local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm

local M = {}

local is_windows = wezterm.target_triple:find("windows")
local separator = is_windows and "\\" or "/"

M.keywords = {}
M.cache = {
	plugin_path = nil,
	require_path = nil,
	error = false,
	fetch_branch = false,
	branch = nil,
}

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

---@return string|nil
local function search_path()
	for _, plugin in ipairs(wezterm.plugin.list()) do
		local found = true
		for _, keyword in ipairs(M.keywords) do
			found = found and plugin.component:find(keyword) ~= nil
		end
		if found then
			M.cache.branch = plugin.plugin_dir:match("#(.*)$")
			M.cache.plugin_path = plugin.plugin_dir
			if M.cache.fetch_branch then
				local success, err = fetch_branch(M.cache.plugin_path, M.cache.branch)
				if not success then
					wezterm.log_error("dev.wezterm: ", err)
					wezterm.emit("dev.wezterm.error_fetching_branch", err)
				end
			end
			M.cache.require_path = plugin.plugin_dir .. separator .. "plugin" .. separator .. "?.lua"
			if M.cache.branch and M.cache.fetch_branch then
				fetch_branch()
			end
			return plugin.plugin_dir
		else
			wezterm.log_error("dev.wezterm: Could not find plugin directory")
			wezterm.emit("dev.wezterm.dir_not_found")
			M.cache.error = true
		end
	end
end

---@return string|nil plugin_path
function M.get_plugin_path()
	if M.cache.error then
		return nil
	elseif M.cache.plugin_path == nil then
		search_path()
	end
	return M.cache.plugin_path
end

---@return string|nil require_path
function M.get_require_path()
	if M.cache.error then
		return nil
	elseif M.cache.require_path == nil then
		search_path()
	end
	return M.cache.require_path
end

function M.set_wezterm_require_path()
	if not M.cache.error then
		package.path = package.path .. ";" .. M.get_require_path()
	end
	wezterm.emit("dev.wezterm.require_path_not_set")
end

---@param keywords table|string
---@param fetch_branch? boolean
function M.setup(keywords, fetch_branch)
	if type(keywords) == "string" then
		M.keywords = { keywords }
	else
		M.keywords = keywords
	end
	if fetch_branch ~= nil then
		M.cache.fetch_branch = fetch_branch
	end
end

return M
