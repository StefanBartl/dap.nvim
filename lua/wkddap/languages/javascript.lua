---@module 'wkddap.languages.javascript'
--- JavaScript/TypeScript: adapter (js-debug-adapter) + launch configurations

local config = require("wkddap.config")

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

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  for _, lang in ipairs({ "javascript", "typescript" }) do
    dap.configurations[lang] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        cwd = "${workspaceFolder}",
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach",
        processId = require("wkddap.utils.validation").pick_process,
        cwd = "${workspaceFolder}",
      },
    }
  end

  return true
end

return M
