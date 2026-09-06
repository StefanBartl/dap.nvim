---@module 'wkddap.core.capabilities'
--- Feature detection for optional companion plugins.
---
--- CDX: `detect()` runs (from core/setup.lua) and populates `_features`, but
--- nothing reads it -- `has()` has no callers and health.lua does its own
--- `pcall(require, ...)` probes. The detection result is computed and discarded.

local M = {}

---@type table<string, boolean>
M._features = {}

--- Probe for nvim-dap and its optional companion plugins.
---@return table<string, boolean> features
function M.detect()
  M._features.dap = pcall(require, "dap")
  M._features.dapui = pcall(require, "dapui")
  M._features.dapview = pcall(require, "dap-view")
  M._features.virtual_text = pcall(require, "nvim-dap-virtual-text")

  return M._features
end

---@param feature string
---@return boolean
function M.has(feature)
  return M._features[feature] == true
end

return M
