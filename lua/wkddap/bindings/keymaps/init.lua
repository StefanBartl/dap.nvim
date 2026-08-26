---@module 'wkddap.bindings.keymaps'
--- Default normal/visual-mode keymaps on top of nvim-dap and the panel UI.
---
--- All keymaps live under a single, user-configurable prefix
--- (`Dap.KeymapOptions.prefix`, default `<leader>d`) and are only installed
--- when `keymaps.enable` is true. Every mapping carries its own `desc`, so
--- which-key (see bindings/which_key.lua) only needs a group label.

local M = {}

--- Install the default DAP keymaps under `opts.prefix`, if enabled.
---@param opts Dap.KeymapOptions
---@return nil
---@see wkddap.bindings.usercmds
function M.setup(opts)
  if not opts.enable then
    return
  end

  local dap = require("dap")
  local prefix = opts.prefix

  local map = require("lib.nvim.bindings.keymap")
  local count = require("lib.nvim.count")
  local desc = function(d)
    return { desc = "[DAP] " .. d, silent = true }
  end

  --- Wrap an nvim-dap step function so a count prefix (`3<leader>ds`) issues
  --- its steps one at a time, each only after the adapter confirms via the
  --- `event_stopped` DAP event that the thread actually stopped from the
  --- previous one. A naive `for i = 1, count do fn() end` is invalid per the
  --- DAP spec: a step request while the thread is still running is not
  --- allowed.
  ---
  --- The chaining itself now lives in `lib.nvim.count.chain`, generalized out
  --- of the version that used to sit here -- the cap, the cleanup on session
  --- end, and the "no listener at all without a count" fast path are its
  --- behavior now, not this file's. What stays here is the only part that is
  --- actually about DAP: which events mean "done" and "gone".
  ---@internal
  ---@param step_fn fun(opts?: table) dap.step_over, dap.step_into, or dap.step_out
  ---@param name string unique suffix for the listener key (one chain per step kind)
  ---@return fun() rhs for the keymap
  local function counted_step(step_fn, name)
    return function()
      count.chain({
        action = step_fn,
        subscribe = function(advance, abort)
          local key = "wkddap.counted_step." .. name
          dap.listeners.after.event_stopped[key] = advance
          -- If the session ends before the chain finishes, don't leave a
          -- listener waiting for a stop event that will never come.
          dap.listeners.after.event_terminated[key] = abort
          dap.listeners.after.event_exited[key] = abort
          return function()
            dap.listeners.after.event_stopped[key] = nil
            dap.listeners.after.event_terminated[key] = nil
            dap.listeners.after.event_exited[key] = nil
          end
        end,
      })
    end
  end

  -- Session control
  map("n", prefix .. "c", dap.continue, desc("Continue"))
  map("n", prefix .. "s", counted_step(dap.step_over, "step_over"), desc("Step Over"))
  map("n", prefix .. "i", counted_step(dap.step_into, "step_into"), desc("Step Into"))
  map("n", prefix .. "o", counted_step(dap.step_out, "step_out"), desc("Step Out"))
  map("n", prefix .. "t", dap.terminate, desc("Terminate"))
  map("n", prefix .. "r", dap.restart, desc("Restart"))

  -- Breakpoints
  map("n", prefix .. "b", dap.toggle_breakpoint, desc("Toggle Breakpoint"))
  map("n", prefix .. "B", function()
    require("wkddap.core.breakpoints").prompt_condition()
  end, desc("Conditional Breakpoint"))
  map("n", prefix .. "L", function()
    require("wkddap.core.breakpoints").prompt_log_point()
  end, desc("Log Point"))
  map("n", prefix .. "l", dap.list_breakpoints, desc("List Breakpoints"))

  -- UI (routed through the active provider: nvim-dap-view or nvim-dap-ui)
  local ui = function()
    return require("wkddap.ui.provider")
  end
  map("n", prefix .. "u", function()
    ui().toggle()
  end, desc("Toggle UI"))
  map("n", prefix .. "e", function()
    ui().eval()
  end, desc("Evaluate Expression"))
  map("v", prefix .. "e", function()
    ui().eval()
  end, desc("Evaluate Selection"))

  -- REPL
  map("n", prefix .. "R", dap.repl.open, desc("Open REPL"))
end

return M
