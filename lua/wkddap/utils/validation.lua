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
    -- nvim-dap resumes `co` and blocks waiting for it, so a cancelled pick
    -- must still resume (with nil) or the DAP launch hangs forever --
    -- hence on_cancel, which kit.select guarantees fires exactly once for
    -- a dismissal, an empty list, or a float that could not open.
    require("lib.nvim.ui.kit").select({
      items = vim.fn.systemlist("ps -eo pid,comm"),
      title = "Select process:",
      on_select = function(choice)
        coroutine.resume(co, tonumber(choice:match("^%s*(%d+)")))
      end,
      on_cancel = function()
        coroutine.resume(co, nil)
      end,
    })
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
