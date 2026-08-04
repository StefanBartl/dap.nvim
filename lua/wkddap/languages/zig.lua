---@module 'wkddap.languages.zig'
--- Zig: adapter (CodeLLDB/lldb) + launch configurations

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
      -- nvim-dap resolves config functions inside coroutine.wrap(), so an
      -- async prompt works via the same yield/resume idiom nvim-dap's own
      -- async pickers use: yield, let kit.input's on_submit resume the
      -- suspended coroutine with the typed value.
      program = function()
        local co = coroutine.running()
        require("lib.nvim.ui.kit").input({
          title = "Path to executable: ",
          default = vim.fn.getcwd() .. "/zig-out/bin/",
          completion = "file",
          on_submit = function(input) coroutine.resume(co, input) end,
          on_cancel = function() coroutine.resume(co, "") end,
        })
        return paths.normalize(coroutine.yield())
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
        local co = coroutine.running()
        require("lib.nvim.ui.kit").input({
          title = "Path to executable: ",
          default = vim.fn.getcwd() .. "/zig-out/bin/",
          completion = "file",
          on_submit = function(input) coroutine.resume(co, input) end,
          on_cancel = function() coroutine.resume(co, "") end,
        })
        return paths.normalize(coroutine.yield())
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }

  return true
end

return M
