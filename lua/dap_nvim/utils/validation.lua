---@module 'dap_nvim.utils.validation'
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
    vim.ui.select(vim.fn.systemlist("ps -eo pid,comm"), {
      prompt = "Select process:",
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice then
        coroutine.resume(co, tonumber(choice:match("^%s*(%d+)")))
      else
        coroutine.resume(co, nil)
      end
    end)
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
