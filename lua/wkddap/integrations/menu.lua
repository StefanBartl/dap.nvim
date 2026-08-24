---@module 'wkddap.integrations.menu'
---@brief Context-menu entries for nvzone/menu (soft, opt-in integration).
---@description
--- dap.nvim does not depend on a menu plugin. Instead it *provides* a list of
--- entries in the shape `lib.nvim.contextmenu` (and, transitively, nvzone/menu)
--- expects, and a host — typically the user's own RightMouse dispatcher —
--- composes them into its own menu, e.g.:
--- >
---   local items = require("wkddap.integrations.menu").items()
---   -- prepend `items` to your custom menu table, then menu.open(composed)
--- <
--- Debugging is a general/any-buffer action (breakpoints, stepping) rather
--- than filetype-scoped, so every entry is offered unconditionally — exactly
--- like the default keymaps (bindings/keymaps/init.lua), which call straight
--- into nvim-dap without checking for an active session first and rely on
--- nvim-dap's own no-op-if-no-session behavior. Opt-out entirely via
--- `config.menu.enable`.

local contextmenu = require("lib.nvim.contextmenu")

local M = {}

--- Build the dap.nvim context-menu entries.
--- Returns an empty list when the integration is disabled or nvim-dap isn't
--- installed, so a host can safely `vim.list_extend` it unconditionally.
---@param opts? table Reserved for future context-scoping; unused today.
---@return Lib.ContextMenu.Item[]
function M.items(opts)
  local cfg = require("wkddap.config").get()
  if cfg.menu and cfg.menu.enable == false then
    return {}
  end

  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return {}
  end

  local ui = function()
    return require("wkddap.ui.provider")
  end

  local out = {}

  -- Session control
  contextmenu.group(
    out,
    contextmenu.entry(true, "  Continue", dap.continue, "<leader>dc"),
    contextmenu.entry(true, "  Step Over", dap.step_over, "<leader>ds"),
    contextmenu.entry(true, "  Step Into", dap.step_into, "<leader>di"),
    contextmenu.entry(true, "  Step Out", dap.step_out, "<leader>do"),
    contextmenu.entry(true, "  Terminate", dap.terminate, "<leader>dt"),
    contextmenu.entry(true, "  Restart", dap.restart, "<leader>dr")
  )

  -- Breakpoints
  contextmenu.group(
    out,
    contextmenu.entry(true, "  Toggle Breakpoint", dap.toggle_breakpoint, "<leader>db"),
    contextmenu.entry(true, "  Conditional Breakpoint…", function()
      require("wkddap.core.breakpoints").prompt_condition()
    end, "<leader>dB"),
    contextmenu.entry(true, "  Log Point…", function()
      require("wkddap.core.breakpoints").prompt_log_point()
    end, "<leader>dL"),
    contextmenu.entry(true, "  List Breakpoints", dap.list_breakpoints, "<leader>dl")
  )

  -- Panel UI
  contextmenu.group(
    out,
    contextmenu.entry(true, "  Toggle DAP UI", function()
      ui().toggle()
    end, "<leader>du"),
    contextmenu.entry(true, "  Evaluate Expression / Selection", function()
      ui().eval()
    end, "<leader>de")
  )

  return out
end

--- Convenience: the dap.nvim entries wrapped as a single nested submenu
--- entry, for hosts that prefer a "DAP ▸" fly-out instead of inline entries.
--- Returns nil when there is nothing to show.
---@param label? string submenu label (default "  DAP")
---@return Lib.ContextMenu.Item|nil
function M.submenu(label)
  return contextmenu.submenu(label or "  DAP", M.items())
end

return M
