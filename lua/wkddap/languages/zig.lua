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
          default = paths.join(vim.fn.getcwd(), "zig-out", "bin", ""),
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
    {
      name = "Launch (build first)",
      type = "lldb",
      request = "launch",
      -- `zig build` used to run through `vim.system(...):wait()`, which froze
      -- Neovim for the entire build -- on a real project that is seconds to
      -- minutes, and the editor showed nothing at all while it happened.
      --
      -- The fix uses the same yield/resume idiom the "Launch" config above
      -- already relies on: nvim-dap resolves config functions inside
      -- `coroutine.wrap()`, so this function can yield once and be resumed
      -- later. The build is spawned, we yield, and the prompt is only opened
      -- from the build's completion callback -- whose `on_submit` then
      -- performs the single resume. Spawning before the yield is safe: the
      -- callback cannot fire until control returns to the event loop, which
      -- is exactly what the yield does.
      program = function()
        local co = coroutine.running()

        local function prompt()
          require("lib.nvim.ui.kit").input({
            title = "Path to executable: ",
            default = paths.join(vim.fn.getcwd(), "zig-out", "bin", ""),
            completion = "file",
            on_submit = function(input)
              coroutine.resume(co, input)
            end,
            on_cancel = function()
              coroutine.resume(co, "")
            end,
          })
        end

        vim.system({ "zig", "build" }, { text = true }, function(res)
          vim.schedule(function()
            -- The old code discarded the exit status entirely and prompted
            -- regardless. That stays -- a failed build may still have left a
            -- previous binary worth debugging -- but it is no longer silent.
            if res.code ~= 0 then
              vim.notify(
                "zig build exited " .. tostring(res.code) .. ": " .. vim.trim(res.stderr or ""),
                vim.log.levels.WARN
              )
            end
            prompt()
          end)
        end)

        return paths.normalize(coroutine.yield())
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }

  return true
end

return M
