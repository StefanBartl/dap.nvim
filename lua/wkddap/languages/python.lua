---@module 'wkddap.languages.python'
--- Python: adapter (debugpy) + launch configurations

local config = require("wkddap.config")
local cross = require("lib.nvim.cross")
local paths = require("wkddap.utils.paths")

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

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "Launch file",
      program = "${file}",
      pythonPath = function()
        local venv = vim.env.VIRTUAL_ENV
        if venv then
          if cross.is_windows() then
            return paths.join(venv, "Scripts", "python.exe")
          end
          return paths.join(venv, "bin", "python")
        end
        return "python3"
      end,
    },
  }

  return true
end

return M
