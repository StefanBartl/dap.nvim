---@module 'dap.adapters.python'
---@brief Python debugging via debugpy

local config = require("dap.config")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("python")
  if not adapter_path then
    return false
  end

  dap.adapters.python = {
    type = "executable",
    command = adapter_path,
    args = { "-m", "debugpy.adapter" },
  }

  return true
end

return M
