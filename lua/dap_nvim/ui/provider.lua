---@module 'dap_nvim.ui.provider'
---@brief Resolves and dispatches to the active DAP panel UI provider.
---@description
--- dap.nvim supports two mutually exclusive panel UIs: `nvim-dap-view` (the
--- default, modern and lighter) and `nvim-dap-ui` (opt-in, richer layout).
--- Exactly one is wired per session; keymaps and user commands route through
--- this module instead of hardcoding either plugin, so `<leader>du` / `:DapToggleUI`
--- behave the same whichever provider is active.

local notify = require("dap_nvim.utils.notify")

local M = {}

---@alias Dap.UiProvider 'dap-view'|'dap-ui'|'auto'|'none'

---@type Dap.UiProvider|nil
local _active = nil

---@param name 'dap-view'|'dap-ui'
---@return boolean
local function installed(name)
  if name == "dap-view" then
    return (pcall(require, "dap-view"))
  end
  return (pcall(require, "dapui"))
end

--- Pick the provider to wire, honouring the configured preference and falling
--- back to the other one when the preferred plugin is not installed.
---@param preference Dap.UiProvider
---@return 'dap-view'|'dap-ui'|nil provider
local function resolve(preference)
  if preference == "none" then
    return nil
  end

  if preference == "auto" then
    if installed("dap-view") then
      return "dap-view"
    end
    if installed("dap-ui") then
      return "dap-ui"
    end
    return nil
  end

  local other = preference == "dap-view" and "dap-ui" or "dap-view"

  if installed(preference) then
    return preference
  end

  if installed(other) then
    notify.warn(
      string.format("ui.provider '%s' is not installed, falling back to '%s'", preference, other)
    )
    return other
  end

  return nil
end

--- Wire the configured provider. Returns the provider that was actually set up.
---@param opts Dap.UiOptions
---@return 'dap-view'|'dap-ui'|nil provider
function M.setup(opts)
  _active = nil

  local provider = resolve(opts.provider or "dap-view")
  if not provider then
    return nil
  end

  local module = provider == "dap-view" and "dap_nvim.ui.dapview" or "dap_nvim.ui.dapui"
  local ok, impl = pcall(require, module)
  if not ok then
    return nil
  end

  local ok_setup, done = pcall(impl.setup, opts)
  if not ok_setup or done == false then
    return nil
  end

  _active = provider
  return provider
end

---@return 'dap-view'|'dap-ui'|nil
function M.active()
  return _active
end

--- Call `fn_name` on the active provider, or report that no UI is available.
---@param actions table<string, fun():nil>
---@param what string Human-readable action name, used in the fallback message.
local function dispatch(actions, what)
  local provider = _active
  if not provider then
    notify.warn(
      string.format("%s: no DAP UI active (install nvim-dap-view or nvim-dap-ui)", what)
    )
    return
  end

  local action = actions[provider]
  if not action then
    notify.warn(string.format("%s is not supported by '%s'", what, provider))
    return
  end

  local ok, err = pcall(action)
  if not ok then
    notify.error(string.format("%s failed: %s", what, tostring(err)))
  end
end

--- Call `method` on nvim-dap-view, falling back to its user command when the
--- installed version does not expose that function on the module.
---@param method string
---@param command string
local function dap_view_call(method, command)
  local dv = require("dap-view")
  if type(dv[method]) == "function" then
    dv[method]()
    return
  end
  vim.cmd(command)
end

--- Toggle the panel UI of the active provider.
function M.toggle()
  dispatch({
    ["dap-view"] = function()
      dap_view_call("toggle", "DapViewToggle")
    end,
    ["dap-ui"] = function()
      require("dapui").toggle()
    end,
  }, "Toggle UI")
end

--- Evaluate the expression under the cursor / the visual selection.
--- nvim-dap-ui shows a floating evaluation window; nvim-dap-view has no float
--- and instead adds the expression to its watch list.
function M.eval()
  dispatch({
    ["dap-view"] = function()
      dap_view_call("add_expr", "DapViewWatch")
    end,
    ["dap-ui"] = function()
      require("dapui").eval()
    end,
  }, "Evaluate Expression")
end

return M
