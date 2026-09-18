---@module 'wkddap.utils.paths'
--- Path helpers, delegating normalization to lib.nvim for Windows safety.

local normalize = require("lib.nvim.normalize")
local cross = require("lib.nvim.cross")

local M = {}

--- Normalize path separators (Windows-safe)
---@param path string Input path
---@return string normalized_path
function M.normalize(path)
  return normalize.normalize_path(path)
end

--- The platform's native separators: backslashes on Windows, unchanged
--- elsewhere. For arguments handed to a tool that insists on them (netcoredbg
--- rejects forward-slash DLL paths) -- `normalize()` deliberately produces
--- forward slashes everywhere, which is what Neovim itself prefers.
---@param path string
---@return string native_path
function M.native(path)
  if cross.is_windows() then
    return (path:gsub("/", "\\"))
  end
  return path
end

--- Join path segments with the platform separator
---@param ... string Path segments
---@return string joined_path
function M.join(...)
  local parts = { ... }
  local sep = package.config:sub(1, 1)
  return table.concat(parts, sep)
end

--- Get workspace root
---@return string root
function M.workspace_root()
  return vim.fn.getcwd()
end

return M
