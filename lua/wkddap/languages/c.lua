---@module 'wkddap.languages.c'
--- C/C++: adapter (CodeLLDB, also registers plain lldb) + launch configurations

local config = require("wkddap.config")
local paths = require("wkddap.utils.paths")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("c")
  if not adapter_path then
    return false
  end

  dap.adapters.lldb = {
    type = "executable",
    command = adapter_path,
    name = "lldb",
  }

  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = adapter_path,
      args = { "--port", "${port}" },
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

  for _, lang in ipairs({ "c", "cpp" }) do
    dap.configurations[lang] = {
      {
        name = "Launch",
        type = "codelldb",
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
        stopOnEntry = false,
      },
    }
  end

  return true
end

return M
