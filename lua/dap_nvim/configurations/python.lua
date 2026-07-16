---@module 'dap_nvim.configurations.python'
---@brief Launch configurations for Python debugging

local M = {}

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
          return venv .. "/bin/python"
        end
        return "python3"
      end,
    },
  }

  return true
end

return M
