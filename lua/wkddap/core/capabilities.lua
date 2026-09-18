---@module 'wkddap.core.capabilities'
--- Feature detection for optional companion plugins.
---
--- Reads `package.loaded`, never `require`: under a lazy-loading plugin
--- manager the require *is* the load trigger, and detection must not be the
--- reason nvim-dap-ui's whole module tree ends up in every startup -- the
--- wiring in `wkddap.ui` requires exactly the provider it was configured to
--- use. So "not loaded" here means "not loaded yet", not "not installed".
---
--- CDX: `detect()` runs (from core/setup.lua) and populates `_features`, but
--- nothing reads it -- `has()` has no callers and health.lua does its own
--- `pcall(require, ...)` probes. The detection result is computed and discarded.

local M = {}

---@type table<string, boolean>
M._features = {}

---@type table<string, string>  feature name -> module name
local MODULES = {
  dap = "dap",
  dapui = "dapui",
  dapview = "dap-view",
  virtual_text = "nvim-dap-virtual-text",
}

--- Record which of nvim-dap and its optional companion plugins are loaded.
---@return table<string, boolean> features
function M.detect()
  for feature, module in pairs(MODULES) do
    M._features[feature] = package.loaded[module] ~= nil
  end

  return M._features
end

---@param feature string
---@return boolean
function M.has(feature)
  return M._features[feature] == true
end

return M
