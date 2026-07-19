---@module 'dap_nvim.utils.executable'
---@brief Executable/Mason binary resolution helpers.
---@description
--- Thin re-export of `lib.nvim.cross.executable`, which this module's own
--- implementation was upstreamed into (identical PATH/Mason-bin resolution
--- logic).

local cross_executable = require("lib.nvim.cross.executable")

local M = {}

--- Check if executable exists in PATH
---@param name string Executable name
---@return boolean exists
M.exists = cross_executable.exists

--- Get executable path
---@param name string Executable name
---@return string|nil path
M.path = cross_executable.path

--- Check Mason installation
---@param package_name string Mason binary name
---@return string|nil path
M.mason_path = cross_executable.mason_bin

return M
