---@module 'dap.core.setup'
---@brief Core initialization: verifies nvim-dap, detects capabilities, inits state.

local notify = require("lib.nvim.notify").create("[dap.nvim]")

local M = {}

--- Setup core DAP functionality
---@param opts Dap.Config
---@return boolean success
function M.setup(opts)
  local ok = pcall(require, "dap")
  if not ok then
    notify.error("nvim-dap (mfussenegger/nvim-dap) not installed — dap.nvim is a config layer on top of it")
    return false
  end

  -- Note: nvim-dap has no set_log_level(); logging is controlled via the
  -- NVIM_DAP_LOG_LEVEL env var.
  if opts.log_level then
    vim.env.NVIM_DAP_LOG_LEVEL = tostring(opts.log_level)
  end

  local ok_cap, capabilities = pcall(require, "dap.core.capabilities")
  if ok_cap then
    pcall(capabilities.detect)
  end

  local ok_state, state = pcall(require, "dap.core.state")
  if ok_state then
    pcall(state.init)
  end

  return true
end

return M
