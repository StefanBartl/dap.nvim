---@module 'dap_nvim.adapters.javascript'
---@brief JavaScript/TypeScript debugging via js-debug-adapter

local config = require("dap_nvim.config")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("javascript")
  if not adapter_path then
    return false
  end

  local mason_pkg_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter"
  local adapter_script = mason_pkg_path .. "/js-debug/src/dapDebugServer.js"

  dap.adapters["pwa-node"] = {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = {
      command = "node",
      args = { adapter_script, "${port}" },
    },
  }

  return true
end

return M
