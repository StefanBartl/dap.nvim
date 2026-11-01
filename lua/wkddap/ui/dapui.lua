---@module 'wkddap.ui.dapui'
--- nvim-dap-ui setup: layout + auto-open/close listeners.
---
--- Opt-in alternative to the default nvim-dap-view provider; selected via
--- `ui.provider = "dap-ui"`. See ui/provider.lua.

local config = require("wkddap.config")
local listeners = require("wkddap.ui.listeners")

local M = {}

--- Set up nvim-dap-ui as the panel UI provider.
---@param opts Dap.UiOptions
---@return boolean success
---@see wkddap.ui.dapview
function M.setup(opts)
  local ok_dapui, dapui = pcall(require, "dapui")
  if not ok_dapui then
    return false
  end

  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  dapui.setup(opts.dap_ui or {
    layouts = config.dapui_layout,
  })

  listeners.open_close(dap, "dapui_config", function()
    dapui.open()
  end, function()
    dapui.close()
  end)

  return true
end

return M
