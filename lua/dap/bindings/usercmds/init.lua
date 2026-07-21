---@module 'dap.bindings.usercmds'
---@brief Registers :Dap <subcommand>, one verb built via lib.nvim's
---@brief composer (:Verb sub … + <Tab> completion + Markdown docgen).
---@description
--- All ten actions mirror the default keymaps 1:1 (see
--- bindings/keymaps/init.lua) but are independent entry points — the
--- keymaps call dap()/ui() Lua functions directly, not these commands.

local composer = require("lib.nvim.usercmd.composer")

local M = {}

function M.setup()
  local function dap()
    return require("dap")
  end
  local function ui()
    return require("dap.ui.provider")
  end

  composer.verb("Dap", {
    desc = "nvim-dap session, breakpoint, and UI control",
    routes = {
      { path = { "continue" }, desc = "Continue", run = function() dap().continue() end },
      { path = { "step-over" }, desc = "Step Over", run = function() dap().step_over() end },
      { path = { "step-into" }, desc = "Step Into", run = function() dap().step_into() end },
      { path = { "step-out" }, desc = "Step Out", run = function() dap().step_out() end },
      { path = { "terminate" }, desc = "Terminate", run = function() dap().terminate() end },
      { path = { "restart" }, desc = "Restart", run = function() dap().restart() end },
      { path = { "toggle-breakpoint" }, desc = "Toggle Breakpoint", run = function() dap().toggle_breakpoint() end },
      { path = { "list-breakpoints" }, desc = "List Breakpoints", run = function() dap().list_breakpoints() end },
      { path = { "toggle-ui" }, desc = "Toggle UI", run = function() ui().toggle() end },
      { path = { "eval" }, desc = "Evaluate Expression", run = function() ui().eval() end },
    },
  })
end

return M
