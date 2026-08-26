---@module 'wkddap.bindings.keymaps'
--- Default normal/visual-mode keymaps on top of nvim-dap and the panel UI.
---
--- All keys default to sitting under a single, user-configurable prefix
--- (`Dap.KeymapOptions.prefix`, default `<leader>d`) and are only installed
--- when `keymaps.enable` is true.
---
--- Declared through `lib.nvim.bindings.keymap`'s registry, which is what makes
--- each one *individually* overridable: the prefix used to be the only lever,
--- so a user whose `<leader>db` was already taken had to move all fourteen or
--- none. `keymaps = { toggle_breakpoint = "<leader>xb" }` now moves exactly
--- one, and `= false` drops one.
---
--- Every mapping carries its own `desc`, so which-key needs nothing beyond the
--- group label for the prefix -- which the spec below hands it.

local M = {}

--- Install the default DAP keymaps under `opts.prefix`, if enabled.
---@param opts Dap.KeymapOptions
---@param which_key boolean|nil  # `false` skips the group label only.
---@return Lib.Keymap.Registered[]
---@see wkddap.bindings.usercmds
function M.setup(opts, which_key)
  local dap = require("dap")
  local prefix = opts.prefix

  local keymap = require("lib.nvim.bindings.keymap")
  local count = require("lib.nvim.count")

  --- Wrap an nvim-dap step function so a count prefix (`3<leader>ds`) issues
  --- its steps one at a time, each only after the adapter confirms via the
  --- `event_stopped` DAP event that the thread actually stopped from the
  --- previous one. A naive `for i = 1, count do fn() end` is invalid per the
  --- DAP spec: a step request while the thread is still running is not
  --- allowed.
  ---
  --- The chaining itself lives in `lib.nvim.count.chain`, generalized out of
  --- the version that used to sit here -- the cap, the cleanup on session end,
  --- and the "no listener at all without a count" fast path are its behavior
  --- now, not this file's. What stays here is the only part that is actually
  --- about DAP: which events mean "done" and "gone".
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

  --- The active UI provider (nvim-dap-view or nvim-dap-ui).
  ---@return table
  local function ui()
    return require("wkddap.ui.provider")
  end

  ---@type Lib.Keymap.Spec
  local spec = {
    prefix = prefix,
    which_key = which_key ~= false and { group = "DAP" } or nil,
    order = {
      "continue",
      "step_over",
      "step_into",
      "step_out",
      "terminate",
      "restart",
      "toggle_breakpoint",
      "conditional_breakpoint",
      "log_point",
      "list_breakpoints",
      "toggle_ui",
      "eval",
      "repl",
    },
    actions = {
      -- Session control
      continue = { default = prefix .. "c", rhs = dap.continue, desc = "Continue" },
      step_over = {
        default = prefix .. "s",
        rhs = counted_step(dap.step_over, "step_over"),
        desc = "Step Over",
      },
      step_into = {
        default = prefix .. "i",
        rhs = counted_step(dap.step_into, "step_into"),
        desc = "Step Into",
      },
      step_out = {
        default = prefix .. "o",
        rhs = counted_step(dap.step_out, "step_out"),
        desc = "Step Out",
      },
      terminate = { default = prefix .. "t", rhs = dap.terminate, desc = "Terminate" },
      restart = { default = prefix .. "r", rhs = dap.restart, desc = "Restart" },

      -- Breakpoints
      toggle_breakpoint = {
        default = prefix .. "b",
        rhs = dap.toggle_breakpoint,
        desc = "Toggle Breakpoint",
      },
      conditional_breakpoint = {
        default = prefix .. "B",
        rhs = function()
          require("wkddap.core.breakpoints").prompt_condition()
        end,
        desc = "Conditional Breakpoint",
      },
      log_point = {
        default = prefix .. "L",
        rhs = function()
          require("wkddap.core.breakpoints").prompt_log_point()
        end,
        desc = "Log Point",
      },
      list_breakpoints = {
        default = prefix .. "l",
        rhs = dap.list_breakpoints,
        desc = "List Breakpoints",
      },

      -- UI, routed through the active provider
      toggle_ui = {
        default = prefix .. "u",
        rhs = function()
          ui().toggle()
        end,
        desc = "Toggle UI",
      },

      -- One key, one intent, two modes -- and two labels, because what is
      -- evaluated differs: whatever is under the cursor, or the selection.
      eval = {
        default = prefix .. "e",
        binds = {
          {
            mode = "n",
            rhs = function()
              ui().eval()
            end,
            desc = "Evaluate Expression",
          },
          {
            mode = "v",
            rhs = function()
              ui().eval()
            end,
            desc = "Evaluate Selection",
          },
        },
      },

      -- REPL
      repl = { default = prefix .. "R", rhs = dap.repl.open, desc = "Open REPL" },
    },
  }

  return keymap.register("DAP", spec, opts)
end

return M
