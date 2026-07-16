---@module 'dap_nvim.configurations.go'
---@brief Launch configurations for Go debugging

local M = {}

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
