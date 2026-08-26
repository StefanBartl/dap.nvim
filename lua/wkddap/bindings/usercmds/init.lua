---@module 'wkddap.bindings.usercmds'
--- Registers :Dap <subcommand>, one verb built via lib.nvim's
--- composer (:Verb sub … + <Tab> completion + Markdown docgen).
---
--- Every action mirrors a default keymap 1:1 (see bindings/keymaps/init.lua)
--- but is an independent entry point — the keymaps call dap()/ui() Lua
--- functions directly, not these commands.

local composer = require("lib.nvim.bindings.usercmd.composer")

local M = {}

--- Register the :Dap user command and all its subcommands.
---@return nil
---@see wkddap.bindings.keymaps
function M.setup()
  local function dap()
    return require("dap")
  end
  local function ui()
    return require("wkddap.ui.provider")
  end

  composer.verb("Dap", {
    desc = "nvim-dap session, breakpoint, and UI control",
    routes = {
      {
        path = { "continue" },
        desc = "Continue",
        run = function()
          dap().continue()
        end,
      },
      {
        path = { "step-over" },
        desc = "Step Over",
        run = function()
          dap().step_over()
        end,
      },
      {
        path = { "step-into" },
        desc = "Step Into",
        run = function()
          dap().step_into()
        end,
      },
      {
        path = { "step-out" },
        desc = "Step Out",
        run = function()
          dap().step_out()
        end,
      },
      {
        path = { "terminate" },
        desc = "Terminate",
        run = function()
          dap().terminate()
        end,
      },
      {
        path = { "restart" },
        desc = "Restart",
        run = function()
          dap().restart()
        end,
      },
      {
        path = { "toggle-breakpoint" },
        desc = "Toggle Breakpoint",
        run = function()
          dap().toggle_breakpoint()
        end,
      },
      {
        path = { "conditional-breakpoint" },
        desc = "Conditional Breakpoint (condition, or prompts when omitted)",
        run = function(ctx)
          if #ctx.rest > 0 then
            dap().set_breakpoint(table.concat(ctx.rest, " "))
            return
          end
          require("wkddap.core.breakpoints").prompt_condition()
        end,
      },
      {
        path = { "log-point" },
        desc = "Log Point (message, or prompts when omitted)",
        run = function(ctx)
          if #ctx.rest > 0 then
            dap().set_breakpoint(nil, nil, table.concat(ctx.rest, " "))
            return
          end
          require("wkddap.core.breakpoints").prompt_log_point()
        end,
      },
      {
        path = { "list-breakpoints" },
        desc = "List Breakpoints",
        run = function()
          dap().list_breakpoints()
        end,
      },
      {
        path = { "toggle-ui" },
        desc = "Toggle UI",
        run = function()
          ui().toggle()
        end,
      },
      {
        path = { "eval" },
        desc = "Evaluate Expression",
        run = function()
          ui().eval()
        end,
      },
      {
        path = { "repl" },
        desc = "Open REPL",
        run = function()
          dap().repl.open()
        end,
      },
    },
  })
end

return M
