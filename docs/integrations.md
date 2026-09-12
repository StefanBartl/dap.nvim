# Integrations

## Context menu (nvzone/menu)

`wkddap.integrations.menu` contributes context-aware entries in the shape
[nvzone/menu](https://github.com/nvzone/menu) expects. dap.nvim has **no**
dependency on `menu` and never opens a context menu itself; a host — typically
your own `<RightMouse>` dispatcher — composes these entries into its own menu:

```lua
local dap_menu = require("wkddap.integrations.menu")

local items = dap_menu.items()   -- { { name, cmd, rtxt }, … } (possibly empty)
local sub   = dap_menu.submenu() -- { name = "  DAP", items = {…} } | nil

-- e.g. in a RightMouse handler:
--   require("menu").open(dap_menu.items(), { mouse = true })
```

Covers session control (continue, step over/into/out, terminate, restart),
breakpoints (toggle, conditional, log point, list) and the panel UI (toggle,
evaluate expression or selection) — the same actions as the default keymaps.
Opt out entirely with `menu = { enable = false }`.

- **Module:** `lua/wkddap/integrations/menu.lua` (`M.items`, `M.submenu`)
- **Config:** `opts.menu.enable` (default `true`)

Full entry-by-entry reference: [FEATURES/CONTROLS.md](FEATURES/CONTROLS.md#right-click-context-menu-nvzonemenu).
