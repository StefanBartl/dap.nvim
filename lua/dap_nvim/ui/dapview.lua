---@module 'dap_nvim.ui.dapview'
---@brief nvim-dap-view setup: user options + auto-open/close listeners.
---@description
--- The default panel UI. Mirrors the nvim-dap-ui wiring (see ui/dapui.lua) so
--- both providers open on `event_initialized` and close on session end.

local M = {}

---@param opts Dap.UiOptions
---@return boolean success
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

  dap.listeners = dap.listeners or { before = {}, after = {} }
  dap.listeners.before = dap.listeners.before or {}
  dap.listeners.after = dap.listeners.after or {}

  dap.listeners.after.event_initialized = dap.listeners.after.event_initialized or {}
  dap.listeners.before.event_terminated = dap.listeners.before.event_terminated or {}
  dap.listeners.before.event_exited = dap.listeners.before.event_exited or {}

  dap.listeners.after.event_initialized["dap_nvim_dapview"] = function()
    pcall(dap_view.open)
  end

  dap.listeners.before.event_terminated["dap_nvim_dapview"] = function()
    pcall(dap_view.close)
  end

  dap.listeners.before.event_exited["dap_nvim_dapview"] = function()
    pcall(dap_view.close)
  end

  return true
end

return M
