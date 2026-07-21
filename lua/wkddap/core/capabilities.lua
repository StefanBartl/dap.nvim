---@module 'dap.core.capabilities'
---@brief Feature detection for optional companion plugins.

local M = {}

---@type table<string, boolean>
M._features = {}

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
