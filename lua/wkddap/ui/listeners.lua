---@module 'wkddap.ui.listeners'
--- Registering `dap.listeners.<when>.<event>[<key>]` handlers.
---
--- nvim-dap creates the per-event tables lazily (via a metatable); a plain table (an older nvim-dap, a
--- test double) may not have them yet. This is the one place that creates them, so the UI providers and
--- the memory view do not each repeat the bootstrap.

local M = {}

---Register `fn` as listener `key` of `dap.listeners[when][event]`, creating the tables that are missing.
---@param dap table nvim-dap (or a double with `listeners`)
---@param when "before"|"after"
---@param event string e.g. "event_initialized"
---@param key string unique listener key, so a re-setup replaces instead of stacking
---@param fn function
function M.set(dap, when, event, key, fn)
  dap.listeners = dap.listeners or { before = {}, after = {} }
  dap.listeners.before = dap.listeners.before or {}
  dap.listeners.after = dap.listeners.after or {}
  local stage = dap.listeners[when]
  stage[event] = stage[event] or {}
  stage[event][key] = fn
end

---The panel UI pattern of both providers: `open()` once the session is initialized, `close()` when it
---terminates or exits.
---@param dap table
---@param key string
---@param open function
---@param close function
function M.open_close(dap, key, open, close)
  M.set(dap, "after", "event_initialized", key, open)
  M.set(dap, "before", "event_terminated", key, close)
  M.set(dap, "before", "event_exited", key, close)
end

return M
