---@module 'dap.ui.virtual_text'
---@brief nvim-dap-virtual-text setup (soft dependency).

local config = require("dap.config")

local M = {}

function M.setup()
  local ok, vt = pcall(require, "nvim-dap-virtual-text")
  if not ok then
    return
  end

  vt.setup(config.virtual_text)
end

return M
