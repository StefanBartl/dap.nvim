---@module 'dap_nvim.utils.notify'
---@brief Thin, prefixed wrapper over lib.nvim.notify for dap.nvim modules.

local notify = require("lib.nvim.notify").create("[dap.nvim]")

local M = {}

---@param msg string
function M.info(msg)
  notify.info(msg)
end

---@param msg string
function M.warn(msg)
  notify.warn(msg)
end

---@param msg string
function M.error(msg)
  notify.error(msg)
end

return M
