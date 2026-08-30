> **Active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

# dap.nvim

```
       __
  ____/ /___ _____
 / __  / __ `/ __ \
/ /_/ / /_/ / /_/ /
\__,_/\__,_/ .___/
          /_/
    adapters & launch configs for nvim-dap, batteries included
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-active%20development-blue)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)

> 💡 Pairs well with [debugging.nvim](https://github.com/StefanBartl/debugging.nvim):
> dap.nvim wires up Debug Adapter Protocol sessions (breakpoints, stepping,
> launch configs) for eight languages, while debugging.nvim inspects live
> editor state (buffers, autocmds, messages) at runtime.

---

A config layer on top of [nvim-dap](https://github.com/mfussenegger/nvim-dap)
that registers adapters and launch configurations for eleven targets (Lua,
JavaScript/TypeScript, C/C++, Go, Python, Rust, Zig, Assembly, Bash, C#/.NET,
and Chrome-based browser debugging), auto-detects
and validates adapter binaries (with Mason fallback), wires up
nvim-dap-ui/nvim-dap-virtual-text, and ships user-configurable keymaps,
commands, and a which-key group label. Built on
[lib.nvim](https://github.com/StefanBartl/lib.nvim) as a deliberate shared
dependency.

## Table of Contents

- [Quickstart](#quickstart)
- [Documentation](#documentation)

## Quickstart

```lua
-- lazy.nvim
{
  "StefanBartl/dap.nvim",
  dependencies = {
    "StefanBartl/lib.nvim",
    "mfussenegger/nvim-dap",
    "igorlfs/nvim-dap-view",      -- default panel UI
    "theHamsta/nvim-dap-virtual-text", -- optional
    "jbyuki/one-small-step-for-vimkind", -- optional, Lua debugging
  },
  event = "VeryLazy",
  opts = {},
}
```

Then verify everything is wired up correctly:

```vim
:checkhealth wkddap
```

## Menu integration (nvzone/menu)

dap.nvim does not depend on [nvzone/menu](https://github.com/nvzone/menu) — it
only *contributes* entries in the shape it expects. A host (typically your
own `<RightMouse>` dispatcher) composes them into its own menu:

```lua
local dap_menu = require("wkddap.integrations.menu")

local items = dap_menu.items()      -- { { name, cmd, rtxt }, … } (possibly empty)
local sub = dap_menu.submenu()      -- { name = "  DAP", items = {…} } | nil

-- e.g. in a RightMouse handler:
--   require("menu").open(dap_menu.items(), { mouse = true })
```

Covers session control (Continue/Step Over/Step Into/Step Out/Terminate/
Restart), breakpoints (Toggle/Conditional/Log Point/List), and the panel UI
(Toggle DAP UI, Evaluate Expression/Selection) — the same actions as the
default keymaps. Opt out entirely with `menu = { enable = false }`.

## Documentation

- [Features](docs/FEATURES/README.md) — languages, adapters, panel UI, keymaps/commands, health checks.
- [Installation](docs/installation.md) — requirements, lazy.nvim/packer.nvim setup, and adapter binary installation.
- [Configuration](docs/configuration.md) — full `setup()` options and their defaults.
- [Panel UI](docs/panel-ui.md) — choosing between nvim-dap-view and nvim-dap-ui via `ui.provider`.
- [Commands and Keymaps](docs/commands.md) — quick reference for default keymaps and `:Dap*` user commands.
- [docs/BINDINGS.md](docs/BINDINGS.md) — full cheatsheet of every keymap, user command, and autocommand.
- [Workflow](docs/WORKFLOW.md) — how the pieces combine in daily debugging use, with gotchas.
- [Health Check](docs/health.md) — what `:checkhealth wkddap` verifies.
- [Architecture](docs/architecture.md) — module layout and file responsibilities.

## License

MIT — see [LICENSE](LICENSE).
