---@module 'dap.utils.validation'
---@brief Small validators used by adapter/configuration modules.

local M = {}

--- Pick a process ID for attach-mode debugging (used by JS/TS "Attach").
---@return thread|nil pid
function M.pick_process()
  local co = coroutine.running()
  if not co then
    return nil
  end

  return coroutine.create(function()
    -- kit.select's on_select never fires on cancel (Esc/q just closes),
    -- unlike vim.ui.select which always invoked its callback. nvim-dap
    -- resumes `co` and blocks waiting for it, so cancelling must still
    -- resume with nil or the DAP launch hangs forever. Guard via on_close,
    -- deferred one tick so a real selection's on_select (which runs
    -- synchronously right after close) has already resumed by the time
    -- this runs.
    local resumed = false
    local surf = require("lib.nvim.ui.kit").select({
      items = vim.fn.systemlist("ps -eo pid,comm"),
      title = "Select process:",
      on_select = function(choice)
        resumed = true
        coroutine.resume(co, choice and tonumber(choice:match("^%s*(%d+)")) or nil)
      end,
    })
    if surf then
      surf:on_close(function()
        vim.schedule(function()
          if not resumed then
            coroutine.resume(co, nil)
          end
        end)
      end)
    end
  end)
end

--- Validate that a path exists and is a file
---@param path string File path
---@return boolean valid, string? error
function M.validate_file(path)
  if not path or path == "" then
    return false, "Empty path"
  end

  local ok, stat = pcall(vim.uv.fs_stat, path)
  if not ok or not stat then
    return false, "File not found: " .. path
  end

  if stat.type ~= "file" then
    return false, "Not a file: " .. path
  end

  return true, nil
end

return M
