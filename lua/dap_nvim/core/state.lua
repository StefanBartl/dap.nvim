---@module 'dap_nvim.core.state'
---@brief Minimal runtime session state.

local M = {}

---@type table
M._state = {
  initialized = false,
  session_active = false,
}

function M.init()
  M._state.initialized = true
  return true
end

function M.is_initialized()
  return M._state.initialized
end

---@param active boolean
function M.set_session_active(active)
  M._state.session_active = active
end

function M.is_session_active()
  return M._state.session_active
end

return M
