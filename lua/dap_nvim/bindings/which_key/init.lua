---@module 'dap_nvim.bindings.which_key'
---@brief Optional, guarded which-key group label for the DAP keymap prefix.
---@description
--- which-key is a **soft** dependency: if it is not installed this is a no-op.
--- Individual keys already carry their own `desc` (see bindings/keymaps.lua),
--- so only a group label for the shared prefix is registered. Supports both
--- the which-key v3 (`add`) and v2 (`register`) APIs.

local M = {}

---Register the dap.nvim group label with which-key, if available.
---@param prefix string The configured keymap prefix (default "<leader>d")
---@return boolean registered
function M.setup(prefix)
  local ok, wk = pcall(require, "which-key")
  if not ok or type(wk) ~= "table" then
    return false
  end

  if type(wk.add) == "function" then
    -- which-key v3
    wk.add({ { prefix, group = "DAP" } })
    return true
  elseif type(wk.register) == "function" then
    -- which-key v2
    wk.register({ [prefix] = { name = "+DAP" } })
    return true
  end

  return false
end

---Whether which-key is installed (for :checkhealth reporting).
---@return boolean
function M.available()
  local ok, wk = pcall(require, "which-key")
  return ok and type(wk) == "table"
end

return M
