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
      -- Async prompt via nvim-dap's coroutine.wrap() config resolution; see
      -- docs/FEATURES/LANGUAGES.md.
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
      -- Non-blocking `zig build` before the prompt (it used to run through
      -- `vim.system(...):wait()`, freezing the editor for the whole build).
      -- Same coroutine.wrap() idiom as "Launch" above: spawn the build, yield,
      -- and open the prompt only from the build's completion callback, which
      -- performs the single resume. Spawning before the yield is safe -- the
      -- callback cannot fire until the yield returns control to the event loop.
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

        -- Explicit cwd (not the implicit inherited editor cwd): "zig build"
        -- must run against the project being debugged, not whatever ambient
        -- directory Neovim happens to be sitting in when the spawn fires.
        vim.system({ "zig", "build" }, { text = true, cwd = paths.workspace_root() }, function(res)
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
