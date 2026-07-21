---@module 'dap.utils.paths'
---@brief Path helpers, delegating normalization to lib.nvim for Windows safety.

local normalize = require("lib.nvim.normalize")

local M = {}

--- Normalize path separators (Windows-safe)
---@param path string Input path
---@return string normalized_path
function M.normalize(path)
  return normalize.normalize_path(path)
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
