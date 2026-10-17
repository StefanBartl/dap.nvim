---@module 'wkddap.integrations.menu'
---@brief Context-menu entries for nvzone/menu (soft, opt-in integration).
---@description
--- dap.nvim does not depend on a menu plugin. Instead it *provides* a list of
--- entries in the shape `ui.contextmenu` (and, transitively, nvzone/menu)
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

local contextmenu = require("ui.contextmenu")

local M = {}

--- Whether a host that asks first (ui.nvim's `ui.menu`) may show this
--- plugin's fly-out: `integrations.ui_menu` is not false and the `menu` group
--- is not switched off. `items()`/`submenu()` themselves stay governed by
--- `menu` alone, so other hosts are unaffected by `ui_menu`.
---@return boolean
function M.enabled()
  local cfg = require("wkddap.config").get()
  if (cfg.integrations or {}).ui_menu == false then
    return false
  end
  return (cfg.menu or {}).enable ~= false
end

--- The key hint per keymap action, read back from what
--- `bindings.keymaps` actually bound through `lib.nvim.bindings.keymap`'s
--- registry -- so a custom `keymaps.prefix`, a per-action override, or a key
--- dropped with `= false` all show up in the menu as they are mapped, and
--- `keymaps.enable = false` shows no hints at all.
---@param cfg table resolved config
---@return table<string, string> hints action name -> lhs (first normal-mode bind)
local function key_hints(cfg)
  local hints = {}
  if not (cfg.keymaps and cfg.keymaps.enable) then
    return hints
  end
  local ok, keymap = pcall(require, "lib.nvim.bindings.keymap")
  if not ok then
    return hints
  end
  for _, e in ipairs(keymap.registered("DAP")) do
    if e.bound and e.lhs and e.mode == "n" and e.name and hints[e.name] == nil then
      hints[e.name] = e.lhs
    end
  end
  return hints
end

--- Build the dap.nvim context-menu entries.
--- Returns an empty list when the integration is disabled or nvim-dap isn't
--- installed, so a host can safely `vim.list_extend` it unconditionally.
---@param _opts? table Reserved for future context-scoping; unused today.
---@return Ui.ContextMenu.Item[]
function M.items(_opts)
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

  local keys = key_hints(cfg)
  local out = {}

  -- Session control
  contextmenu.group(
    out,
    contextmenu.entry(true, "  Continue", dap.continue, keys.continue),
    contextmenu.entry(true, "  Step Over", dap.step_over, keys.step_over),
    contextmenu.entry(true, "  Step Into", dap.step_into, keys.step_into),
    contextmenu.entry(true, "  Step Out", dap.step_out, keys.step_out),
    contextmenu.entry(true, "  Terminate", dap.terminate, keys.terminate),
    contextmenu.entry(true, "  Restart", dap.restart, keys.restart)
  )

  -- Breakpoints
  contextmenu.group(
    out,
    contextmenu.entry(true, "  Toggle Breakpoint", dap.toggle_breakpoint, keys.toggle_breakpoint),
    contextmenu.entry(true, "  Conditional Breakpoint…", function()
      require("wkddap.core.breakpoints").prompt_condition()
    end, keys.conditional_breakpoint),
    contextmenu.entry(true, "  Log Point…", function()
      require("wkddap.core.breakpoints").prompt_log_point()
    end, keys.log_point),
    contextmenu.entry(true, "  List Breakpoints", dap.list_breakpoints, keys.list_breakpoints)
  )

  -- Panel UI
  contextmenu.group(
    out,
    contextmenu.entry(true, "  Toggle DAP UI", function()
      ui().toggle()
    end, keys.toggle_ui),
    contextmenu.entry(true, "  Evaluate Expression / Selection", function()
      ui().eval()
    end, keys.eval)
  )

  return out
end

--- Convenience: the dap.nvim entries wrapped as a single nested submenu
--- entry, for hosts that prefer a "DAP ▸" fly-out instead of inline entries.
--- Returns nil when there is nothing to show.
---@param label? string submenu label (default "  DAP")
---@return Ui.ContextMenu.Item|nil
function M.submenu(label)
  return contextmenu.submenu(label or "  DAP", M.items())
end

return M
