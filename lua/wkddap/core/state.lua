---@module 'wkddap.core.state'
--- Minimal runtime session state.
---
--- CDX: only `init()` is wired (from core/setup.lua). `set_session_active`
--- has no callers anywhere in the repo, so `session_active` is always false;
--- `is_session_active()` / `is_initialized()` are unread. Vestigial API or
--- unfinished session tracking.

local M = {}

---@type table
M._state = {
  initialized = false,
  session_active = false,
}

--- Mark core state as initialized.
---@return boolean success
function M.init()
  M._state.initialized = true
  return true
end

--- Whether `init()` has run.
---@return boolean
function M.is_initialized()
  return M._state.initialized
end

--- Record whether a DAP session is currently active.
---@param active boolean
---@return nil
function M.set_session_active(active)
  M._state.session_active = active
end

--- Whether a DAP session is currently active.
---@return boolean
function M.is_session_active()
  return M._state.session_active
end

return M
