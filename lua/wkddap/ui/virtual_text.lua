---@module 'wkddap.ui.virtual_text'
--- nvim-dap-virtual-text setup (soft dependency).

local config = require("wkddap.config")

local M = {}

--- Wire nvim-dap-virtual-text with `config.virtual_text`, if installed.
---@return nil
function M.setup()
  local ok, vt = pcall(require, "nvim-dap-virtual-text")
  if not ok then
    return
  end

  vt.setup(config.virtual_text)
end

return M
