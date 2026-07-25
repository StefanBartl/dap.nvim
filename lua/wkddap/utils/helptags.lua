---@module 'dap.utils.helptags'
---@brief Keeps doc/tags current so `:h wkddap-*` works without the user
---@brief having to run `:helptags` by hand after an update.

local M = {}

--- Locate this plugin's own doc/ directory via 'runtimepath', not a
--- hardcoded relative path — lazy.nvim/packer install locations vary.
---@return string|nil
local function doc_dir()
  local found = vim.api.nvim_get_runtime_file("doc/wkddap.txt", false)
  if #found == 0 then
    return nil
  end
  return vim.fn.fnamemodify(found[1], ":h")
end

--- Regenerate doc/tags, but only when it is missing or older than the
--- vimdoc source — `:helptags` is cheap but pointless to re-run every
--- startup.
function M.generate()
  local dir = doc_dir()
  if not dir then
    return
  end

  local txt_stat = vim.uv.fs_stat(dir .. "/wkddap.txt")
  if not txt_stat then
    return
  end

  local tags_stat = vim.uv.fs_stat(dir .. "/tags")
  if tags_stat and tags_stat.mtime.sec >= txt_stat.mtime.sec then
    return
  end

  pcall(vim.cmd.helptags, dir)
end

return M
