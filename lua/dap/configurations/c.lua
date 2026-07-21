---@module 'dap.configurations.c'
---@brief Launch configurations for C/C++ debugging

local paths = require("dap.utils.paths")

local M = {}

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  for _, lang in ipairs({ "c", "cpp" }) do
    dap.configurations[lang] = {
      {
        name = "Launch",
        type = "codelldb",
        request = "launch",
        program = function()
          return paths.normalize(vim.fn.input("Path to executable: ", paths.join(vim.fn.getcwd(), ""), "file"))
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
      },
    }
  end

  return true
end

return M
