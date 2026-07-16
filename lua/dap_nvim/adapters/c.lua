---@module 'dap_nvim.adapters.c'
---@brief C/C++ debugging via CodeLLDB (also registers plain lldb)

local config = require("dap_nvim.config")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("c")
  if not adapter_path then
    return false
  end

  dap.adapters.lldb = {
    type = "executable",
    command = adapter_path,
    name = "lldb",
  }

  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = adapter_path,
      args = { "--port", "${port}" },
    },
  }

  return true
end

return M
