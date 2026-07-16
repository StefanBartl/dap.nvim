---@module 'dap_nvim.utils.executable'
---@brief Executable/Mason binary resolution helpers.

local cross = require("lib.nvim.cross")

local M = {}

--- Check if executable exists in PATH
---@param name string Executable name
---@return boolean exists
function M.exists(name)
  return vim.fn.executable(name) == 1
end

--- Get executable path
---@param name string Executable name
---@return string|nil path
function M.path(name)
  local exe = vim.fn.exepath(name)
  if exe and exe ~= "" then
    return exe
  end
  return nil
end

--- Check Mason installation
---@param package_name string Mason binary name
---@return string|nil path
function M.mason_path(package_name)
  local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/" .. package_name
  if cross.is_windows() then
    mason_bin = mason_bin .. ".cmd"
  end

  local ok, stat = pcall(vim.uv.fs_stat, mason_bin)
  if ok and stat then
    return mason_bin
  end

  return nil
end

return M
