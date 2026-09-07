> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

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
![Status](https://img.shields.io/badge/status-beta-orange)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)

A config layer on top of [nvim-dap](https://github.com/mfussenegger/nvim-dap)
that registers adapters and launch configurations for eleven targets, so that
`opts = {}` is a working debugger rather than the start of an afternoon.

nvim-dap is deliberately unopinionated: it speaks the Debug Adapter Protocol and
leaves every adapter path, launch shape and UI decision to you. This plugin is
the answer to all of those, with the binaries auto-detected and validated.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [Integrations](#integrations)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Features](docs/FEATURES/README.md) — languages, adapters, panel UI, controls, health checks.
- [Installation](docs/installation.md) — requirements, every plugin manager, and adapter binary installation.
- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Panel UI](docs/panel-ui.md) — choosing between nvim-dap-view and nvim-dap-ui via `ui.provider`.
- [Commands and keymaps](docs/commands.md) — the default keys and the `:Dap` subcommands.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand at a glance.
- [Workflow](docs/WORKFLOW.md) — how the pieces combine in daily debugging use, with the gotchas.
- [Health check](docs/health.md) — what `:checkhealth wkddap` verifies.
- [Architecture](docs/architecture.md) — module layout and file responsibilities.

`:help wkddap` is the same reference inside the editor.

---

## What it does

Eleven debug targets, registered and validated:

| | |
| --- | --- |
| Lua | OSV ([one-small-step-for-vimkind](https://github.com/jbyuki/one-small-step-for-vimkind)) — Neovim-native, attach-only |
| JavaScript / TypeScript | `js-debug-adapter` (`pwa-node`) — launch and attach, with a process picker |
| Browser | `js-debug-adapter` (`pwa-chrome`) — attach on port 9222 plus launch, appended to the JS/TS configs rather than replacing them |
| C / C++ | CodeLLDB, which also registers plain `lldb` |
| Rust | CodeLLDB, bootstrapping `rustc`'s own LLDB pretty-printers |
| Zig | CodeLLDB — plain launch, and a "build first" config that runs `zig build` |
| Assembly | GDB, for NASM/GAS/AT&T filetypes |
| Go | Delve (`dlv`) — debug, debug package, debug test |
| Python | `debugpy`, resolving `$VIRTUAL_ENV` before falling back to `python3` |
| Bash | `bash-debug-adapter`, shared by `sh`/`bash`/`zsh`/`ksh` |
| C# / .NET | `netcoredbg`, defaulting the DLL prompt into `bin/Debug/` |

Around that:

- **Adapter auto-detection and validation** — the binary is looked for on `PATH`
  and in the usual per-language locations, with a Mason fallback, and a missing
  or unusable adapter is reported by `:checkhealth` instead of failing silently
  at the moment you press `<leader>dc`.
- **A panel UI you can swap** — nvim-dap-view by default, nvim-dap-ui via
  `ui.provider`, and nvim-dap-virtual-text wired up when installed.
- **Keymaps, commands and a which-key group label**, all user-configurable, with
  the `:Dap` command tree registered independently of whether you enable the
  keymaps.

The module namespace is `wkddap`, not `dap` — `dap` belongs to nvim-dap, and
shadowing it would break every other plugin's `require("dap")`.

---

## Around it

> **[debugging.nvim](https://github.com/StefanBartl/debugging.nvim)** — the other
> half of the same question. dap.nvim runs a Debug Adapter Protocol session over
> your program; debugging.nvim inspects the live editor state around it (buffers,
> autocmds, messages) with no adapter involved.
>
> **[runtime-analysis.nvim](https://github.com/StefanBartl/runtime-analysis.nvim)** —
> when the question is not "what is this variable now" but "was this ever called,
> and how often".
>
> Both are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) and
> [nvim-dap](https://github.com/mfussenegger/nvim-dap) are the real
> dependencies — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the `:Dap` command tree and the shared UI kit |
| [nvim-dap](https://github.com/mfussenegger/nvim-dap) | required — this plugin configures it, it does not replace it |
| A debug adapter per language | required for that language only; see [docs/installation.md](docs/installation.md) for where each comes from |

Optional, each detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view) | The default panel UI |
| [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) | The alternative panel UI, selected with `ui.provider` |
| [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text) | Inline variable values next to the code |
| [one-small-step-for-vimkind](https://github.com/jbyuki/one-small-step-for-vimkind) | Lua debugging — required for that target specifically |
| [mason.nvim](https://github.com/williamboman/mason.nvim) | Fallback location for adapter binaries |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | The `<leader>d` group label |
| [nvzone/menu](https://github.com/nvzone/menu) | A host for the context-menu entries — see [Integrations](#integrations) |

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/dap.nvim",
  dependencies = {
    "StefanBartl/lib.nvim",
    "mfussenegger/nvim-dap",
    "igorlfs/nvim-dap-view",             -- default panel UI
    "theHamsta/nvim-dap-virtual-text",   -- optional
    "jbyuki/one-small-step-for-vimkind", -- optional, Lua debugging
  },
  event = "VeryLazy",
  opts = {},
}
```

`opts = {}` is a complete configuration: every adapter is registered and every
default keymap bound. Other plugin managers and per-language adapter
installation are in [docs/installation.md](docs/installation.md).

---

## Quickstart

Open a file in one of the supported languages, put the cursor on a line, and
start a session:

```vim
:Dap toggle-breakpoint
:Dap continue
```

Or with the default keys — `<leader>db` to break, `<leader>dc` to run.

Before anything else, check that the adapter for your language was actually
found:

```vim
:checkhealth wkddap
```

---

## What you get with the defaults

`keymaps.enable` is on by default; the `:Dap` tree is registered either way.

| Key | Command | Does |
| --- | --- | --- |
| `<leader>dc` | `:Dap continue` | Start or continue the session |
| `<leader>db` | `:Dap toggle-breakpoint` | Toggle a breakpoint on this line |
| `<leader>ds` / `<leader>di` / `<leader>do` | `:Dap step-over` / `step-into` / `step-out` | Step |
| `<leader>du` | `:Dap toggle-ui` | Show or hide the panel |
| `<leader>de` | `:Dap eval` | Evaluate an expression, or the Visual selection |

`:Dap` also carries `terminate`, `restart`, `conditional-breakpoint`,
`log-point`, `list-breakpoints` and `repl`. The full set is the
[bindings cheatsheet](docs/BINDINGS.md).

---

## Integrations

### Context menu

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
evaluate expression or selection) — the same actions as the default keymaps. Opt
out entirely with `menu = { enable = false }`.

---

## Health check

```vim
:checkhealth wkddap
```

Reports, per language, whether its adapter binary was found and whether it
answers; which panel UI provider resolved; and which optional companions are
present. This is the check worth running *before* the first session, because a
missing adapter otherwise only shows up as a session that never starts. Every
line it can print is in [docs/health.md](docs/health.md).

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the project
layout, including what adding a twelfth language involves;
[docs/architecture.md](docs/architecture.md) says which module owns what.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/dap.nvim/issues) to report bugs,
suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/dap.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
