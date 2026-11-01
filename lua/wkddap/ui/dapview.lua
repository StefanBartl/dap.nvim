---@module 'wkddap.ui.dapview'
--- nvim-dap-view setup: user options + auto-open/close listeners.
---
--- The default panel UI. Mirrors the nvim-dap-ui wiring (see ui/dapui.lua) so
--- both providers open on `event_initialized` and close on session end.

local listeners = require("wkddap.ui.listeners")

local M = {}

--- Set up nvim-dap-view as the panel UI provider.
---@param opts Dap.UiOptions
---@return boolean success
---@see wkddap.ui.dapui
function M.setup(opts)
  local ok_view, dap_view = pcall(require, "dap-view")
  if not ok_view then
    return false
  end

  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  -- nvim-dap-view ships sensible defaults; only pass a table when the user
  -- supplied one, so we never fight upstream's schema.
  local ok_setup = pcall(dap_view.setup, opts.dap_view)
  if not ok_setup then
    return false
  end

  listeners.open_close(dap, "dap_dapview", function()
    pcall(dap_view.open)
  end, function()
    pcall(dap_view.close)
  end)

  return true
end

return M
