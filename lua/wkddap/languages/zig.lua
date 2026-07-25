---@module 'dap.languages.zig'
---@brief Zig: adapter (CodeLLDB/lldb) + launch configurations

local config = require("wkddap.config")
local paths = require("wkddap.utils.paths")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("zig")
  if not adapter_path then
    return false
  end

  dap.adapters.lldb = dap.adapters.lldb
    or {
      type = "executable",
      command = adapter_path,
      name = "lldb",
    }

  return true
end

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
        return paths.normalize(
          vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/bin/", "file")
        )
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
        return paths.normalize(
          vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/bin/", "file")
        )
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }

  return true
end

return M
