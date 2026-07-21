---@module 'dap.ui.dapui'
---@brief nvim-dap-ui setup: layout + auto-open/close listeners.
---@description
--- Opt-in alternative to the default nvim-dap-view provider; selected via
--- `ui.provider = "dap-ui"`. See ui/provider.lua.

local config = require("dap.config")

local M = {}

---@param opts Dap.UiOptions
---@return boolean success
function M.setup(opts)
  local ok_dapui, dapui = pcall(require, "dapui")
  if not ok_dapui then
    return false
  end

  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  dap.listeners = dap.listeners or { before = {}, after = {} }
  dap.listeners.before = dap.listeners.before or {}
  dap.listeners.after = dap.listeners.after or {}

  dapui.setup(opts.dap_ui or {
    layouts = config.dapui_layout,
  })

  dap.listeners.after.event_initialized = dap.listeners.after.event_initialized or {}
  dap.listeners.before.event_terminated = dap.listeners.before.event_terminated or {}
  dap.listeners.before.event_exited = dap.listeners.before.event_exited or {}

  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end

  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end

  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end

  return true
end

return M
