---@module 'dap_nvim.adapters.rust'
---@brief Rust debugging via CodeLLDB

local config = require("dap_nvim.config")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("rust")
  if not adapter_path then
    return false
  end

  dap.adapters.codelldb = dap.adapters.codelldb or {
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
