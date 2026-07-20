---@module 'dap_nvim.configurations.zig'
---@brief Launch configurations for Zig debugging

local paths = require("dap_nvim.utils.paths")

local M = {}

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  dap.configurations.zig = {
    {
      name = "Launch",
      type = "lldb",
      request = "launch",
      program = function()
        return paths.normalize(vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/bin/", "file"))
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
    {
      name = "Launch (build first)",
      type = "lldb",
      request = "launch",
      program = function()
        vim.system({ "zig", "build" }):wait()
        return paths.normalize(vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/bin/", "file"))
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }

  return true
end

return M
