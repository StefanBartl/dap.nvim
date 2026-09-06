---@module 'wkddap.languages.assembly'
--- Assembly: adapter (GDB) + launch configurations (NASM/GAS via GDB)

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
        -- Async prompt via nvim-dap's coroutine.wrap() config resolution; see
        -- docs/FEATURES/LANGUAGES.md.
        program = function()
          local co = coroutine.running()
          require("lib.nvim.ui.kit").input({
            title = "Path to executable: ",
            default = paths.join(vim.fn.getcwd(), ""),
            completion = "file",
            on_submit = function(input)
              coroutine.resume(co, input)
            end,
            on_cancel = function()
              coroutine.resume(co, "")
            end,
          })
          return paths.normalize(coroutine.yield())
        end,
        cwd = "${workspaceFolder}",
        stopAtBeginningOfMainSubprogram = false,
      },
    }
  end

  return true
end

return M
