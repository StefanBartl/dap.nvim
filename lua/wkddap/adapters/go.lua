---@module 'dap.adapters.go'
---@brief Go debugging via Delve

local config = require("wkddap.config")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("go")
  if not adapter_path then
    return false
  end

  dap.adapters.go = {
    type = "server",
    port = "${port}",
    executable = {
      command = adapter_path,
      args = { "dap", "-l", "127.0.0.1:${port}" },
    },
  }

  return true
end

return M
