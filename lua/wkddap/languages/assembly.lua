---@module 'dap.languages.assembly'
---@brief Assembly: adapter (GDB) + launch configurations (NASM/GAS via GDB)

local paths = require("wkddap.utils.paths")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  dap.adapters.gdb = {
    type = "executable",
    command = "gdb",
    args = { "-i", "dap" },
  }

  return true
end

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
          return paths.normalize(
            vim.fn.input("Path to executable: ", paths.join(vim.fn.getcwd(), ""), "file")
          )
        end,
        cwd = "${workspaceFolder}",
        stopAtBeginningOfMainSubprogram = false,
      },
    }
  end

  return true
end

return M
