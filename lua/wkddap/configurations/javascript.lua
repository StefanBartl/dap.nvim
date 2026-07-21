---@module 'dap.configurations.javascript'
---@brief Launch configurations for JavaScript/TypeScript debugging

local M = {}

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
