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

  local map = vim.keymap.set
  local desc = function(d)
    return { desc = "[DAP] " .. d, silent = true }
  end

  -- Upper bound on how many chained steps a single count-prefixed keypress
  -- may queue up, so a fat-fingered count (or a session that keeps stopping
  -- forever) can't build an unbounded chain.
  local MAX_CHAINED_STEPS = 1000

  --- Wraps a nvim-dap step function (step_over/step_into/step_out) so that
  --- `vim.v.count1` chained step requests are issued one at a time, each
  --- only after the adapter confirms (via the `event_stopped` DAP event)
  --- that the thread has actually stopped from the previous step. Firing
  --- another step request while the thread is still running from a prior
  --- one is invalid per the DAP spec, so a naive `for i=1,count do fn() end`
  --- is not safe here -- this chains via `dap.listeners.after.event_stopped`
  --- instead (the same extension point used elsewhere in this repo, see
  --- ui/dapui.lua and ui/dapview.lua).
  ---
  --- With no count (the overwhelmingly common case), this calls `step_fn()`
  --- directly and registers no listener at all -- zero behavior change from
  --- before.
  ---@internal
  ---@param step_fn fun(opts?: table) dap.step_over, dap.step_into, or dap.step_out
  ---@param name string unique suffix for the listener key (one chain per step kind)
  ---@return fun() rhs for vim.keymap.set
  local function counted_step(step_fn, name)
    return function()
      local count = vim.v.count1
      if count <= 1 then
        step_fn()
        return
      end

      local key = "wkddap.counted_step." .. name
      -- Steps still owed *beyond* the one fired immediately below.
      local remaining = math.min(count, MAX_CHAINED_STEPS) - 1

      local function cleanup()
        dap.listeners.after.event_stopped[key] = nil
        dap.listeners.after.event_terminated[key] = nil
        dap.listeners.after.event_exited[key] = nil
      end

      dap.listeners.after.event_stopped[key] = function()
        if remaining <= 0 then
          -- The step that satisfies `count` already fired; this stop event
          -- just confirms it landed. Nothing left to do.
          cleanup()
          return
        end
        remaining = remaining - 1
        step_fn()
      end

      -- Safety net: if the session ends before the chain finishes, don't
      -- leave a dangling listener waiting for a stop event that will never
      -- come.
      dap.listeners.after.event_terminated[key] = cleanup
      dap.listeners.after.event_exited[key] = cleanup

      step_fn()
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
    require("lib.nvim.ui.kit").input({
      title = "Breakpoint condition: ",
      on_submit = function(cond) dap.set_breakpoint(cond) end,
    })
  end, desc("Conditional Breakpoint"))
  map("n", prefix .. "L", function()
    require("lib.nvim.ui.kit").input({
      title = "Log message: ",
      on_submit = function(msg) dap.set_breakpoint(nil, nil, msg) end,
    })
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
