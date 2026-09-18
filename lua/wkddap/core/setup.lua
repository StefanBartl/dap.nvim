---@module 'wkddap.core.setup'
--- Core initialization: verifies nvim-dap, detects capabilities, inits state.

local notify = require("lib.nvim.notify").create("[dap.nvim]")
local normalize = require("lib.nvim.normalize")

local M = {}

---nvim-dap's log level *names*, by the `vim.log.levels` value they stand for.
---`dap.set_log_level()` wants the name; it would take the integer too, but
---only by the accident that both enums count TRACE..ERROR as 0..4, and
---`vim.log.levels.OFF` has no counterpart at all -- ERROR is the quietest
---nvim-dap goes.
---@type table<integer, string>
local DAP_LEVEL_NAMES = {
  [vim.log.levels.TRACE] = "TRACE",
  [vim.log.levels.DEBUG] = "DEBUG",
  [vim.log.levels.INFO] = "INFO",
  [vim.log.levels.WARN] = "WARN",
  [vim.log.levels.ERROR] = "ERROR",
  [vim.log.levels.OFF] = "ERROR",
}

---@internal
---Apply `log_level` to nvim-dap's log file. Accepts a `vim.log.levels` value
---or a name ("debug"); anything else is reported and leaves nvim-dap's own
---default in force.
---@param dap table  the loaded nvim-dap module
---@param level any
---@return nil
local function apply_log_level(dap, level)
  local name = DAP_LEVEL_NAMES[normalize.to_log_level(level)]
  if not name then
    notify.warn(
      string.format(
        "log_level %s is not a vim.log.levels value or name -- nvim-dap keeps its own level",
        vim.inspect(level)
      )
    )
    return
  end

  local ok, err = pcall(dap.set_log_level, name)
  if not ok then
    notify.warn(string.format("nvim-dap rejected log level %s: %s", name, tostring(err)))
  end
end

--- Setup core DAP functionality
---@param opts Dap.Config
---@return boolean success
function M.setup(opts)
  local ok, dap = pcall(require, "dap")
  if not ok then
    notify.error(
      "nvim-dap (mfussenegger/nvim-dap) not installed — dap.nvim is a config layer on top of it"
    )
    return false
  end

  if opts.log_level ~= nil then
    apply_log_level(dap, opts.log_level)
  end

  local ok_cap, capabilities = pcall(require, "wkddap.core.capabilities")
  if ok_cap then
    pcall(capabilities.detect)
  end

  local ok_state, state = pcall(require, "wkddap.core.state")
  if ok_state then
    pcall(state.init)
  end

  return true
end

return M
