---@module 'wkddap.languages.go'
--- Go: adapter (Delve) + launch configurations

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

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  dap.configurations.go = {
    {
      type = "go",
      name = "Debug",
      request = "launch",
      program = "${file}",
    },
    {
      type = "go",
      name = "Debug Package",
      request = "launch",
      program = "${fileDirname}",
    },
    {
      type = "go",
      name = "Debug Test",
      request = "launch",
      mode = "test",
      program = "${file}",
    },
  }

  return true
end

return M
