---@module 'wkddap.core.state'
--- Minimal runtime state: just the "core setup has run" marker.

local M = {}

---@type table
M._state = {
  initialized = false,
}

--- Mark core state as initialized.
---@return boolean success
function M.init()
  M._state.initialized = true
  return true
end

return M
