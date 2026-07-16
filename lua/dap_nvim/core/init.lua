---@module 'dap_nvim.core'

local M = {}

---@param opts Dap.Config
---@return boolean success
function M.setup(opts)
  local ok, setup = pcall(require, "dap_nvim.core.setup")
  if not ok then
    return false
  end

  return setup.setup(opts)
end

return M
