---@module 'dap.bindings.keymaps'
---@brief Default normal/visual-mode keymaps on top of nvim-dap and the panel UI.
---@description
--- All keymaps live under a single, user-configurable prefix
--- (`Dap.KeymapOptions.prefix`, default `<leader>d`) and are only installed
--- when `keymaps.enable` is true. Every mapping carries its own `desc`, so
--- which-key (see bindings/which_key.lua) only needs a group label.

local M = {}

---@param opts Dap.KeymapOptions
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

  -- Session control
  map("n", prefix .. "c", dap.continue, desc("Continue"))
  map("n", prefix .. "s", dap.step_over, desc("Step Over"))
  map("n", prefix .. "i", dap.step_into, desc("Step Into"))
  map("n", prefix .. "o", dap.step_out, desc("Step Out"))
  map("n", prefix .. "t", dap.terminate, desc("Terminate"))
  map("n", prefix .. "r", dap.restart, desc("Restart"))

  -- Breakpoints
  map("n", prefix .. "b", dap.toggle_breakpoint, desc("Toggle Breakpoint"))
  map("n", prefix .. "B", function()
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, desc("Conditional Breakpoint"))
  map("n", prefix .. "L", function()
    dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
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
