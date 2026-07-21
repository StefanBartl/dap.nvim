---@module 'dap.configurations.assembly'
---@brief Launch configurations for Assembly debugging (NASM/GAS via GDB)

local paths = require("wkddap.utils.paths")

local M = {}

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  for _, ft in ipairs({ "asm", "nasm", "gas" }) do
    dap.configurations[ft] = {
      {
        name = "Launch",
        type = "gdb",
        request = "launch",
        program = function()
          return paths.normalize(vim.fn.input("Path to executable: ", paths.join(vim.fn.getcwd(), ""), "file"))
        end,
        cwd = "${workspaceFolder}",
        stopAtBeginningOfMainSubprogram = false,
      },
    }
  end

  return true
end

return M
