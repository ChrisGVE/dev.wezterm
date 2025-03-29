local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm

local M = {}

-- compute a hash key from a string
---@param str string
---@return string hashkey
function M.hash(str)
	local hashkey = 5381
	for i = 1, #str do
		hashkey = ((hashkey << 5) + hashkey) + string.byte(str, i)
		hashkey = hashkey & 0xFFFFFFFF
	end
	return string.format("%08x", hashkey)
end

-- generate a hash from an array
---@param arr table
---@return string hashkey
function M.array_hash(arr)
	local str = table.concat(arr, ",")
	return M.hash(str)
end

-- deep copy
---@param original table
---@return any copy
function M.deepcopy(original)
	local copy
	if type(original) == "table" then
		copy = {}
		for k, v in pairs(original) do
			copy[k] = M.deepcopy(v)
		end
	else
		copy = original
	end
	return copy
end
