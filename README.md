<!-- ASCII art banner -->
<pre>
       __
  ____/ /___ _____
 / __  / __ `/ __ \
/ /_/ / /_/ / /_/ /
\__,_/\__,_/ .___/
          /_/
    adapters & launch configs for nvim-dap, batteries included
</pre>

> 💡 Pairs well with [debugging.nvim](https://github.com/StefanBartl/debugging.nvim):
> dap.nvim wires up Debug Adapter Protocol sessions (breakpoints, stepping,
> launch configs) for nine languages, while debugging.nvim inspects live
> editor state (buffers, autocmds, messages) at runtime.

![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)
![Depends](https://img.shields.io/badge/depends-lib.nvim-orange)

---

A config layer on top of [nvim-dap](https://github.com/mfussenegger/nvim-dap)
that registers adapters and launch configurations for nine languages (Lua,
JavaScript/TypeScript, C/C++, Go, Python, Rust, Zig, Assembly), auto-detects
and validates adapter binaries (with Mason fallback), wires up
nvim-dap-ui/nvim-dap-virtual-text, and ships user-configurable keymaps,
commands, and a which-key group label.

Built on [lib.nvim](https://github.com/StefanBartl/lib.nvim) as a deliberate
shared dependency.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Panel UI](#panel-ui)
- [Default Keymaps](#default-keymaps)
- [User Commands](#user-commands)
- [Health Check](#health-check)
- [Architecture](#architecture)

## Features

| Language | Adapter | Notes |
|---|---|---|
| Lua | OSV (`one-small-step-for-vimkind`) | Neovim-native, attach-only |
| JavaScript/TypeScript | `js-debug-adapter` | Node.js; via Mason |
| C/C++ | CodeLLDB (also registers plain `lldb`) | Via Mason |
| Go | Delve (`dlv`) | Go 1.16+ |
| Python | `debugpy` | Python 3.7+ |
| Rust | CodeLLDB, with `rustc`-provided pretty printers | Cargo-friendly launch config |
| Zig | CodeLLDB/`lldb` | Includes a "build first" launch config |
| Assembly | GDB | NASM/GAS/AT&T filetypes |

Aliases: `typescript`/`javascriptreact`/`typescriptreact` → `javascript`,
`cpp`/`c++` → `c`, `asm`/`nasm`/`gas` → `assembly`.

Every adapter/configuration module is isolated and only registered if its
binary (or Neovim plugin, for Lua) is actually available — see
[Health Check](#health-check).

## Requirements

- Neovim 0.9+
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) (required — dap.nvim
  configures it, it does not replace it)
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)
- Panel UI (optional, pick one): [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view)
  (default) **or** [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) (opt-in
  via `ui.provider`) — see [Panel UI](#panel-ui)
- Optional: [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text),
  [which-key.nvim](https://github.com/folke/which-key.nvim), and
  [mason.nvim](https://github.com/williamboman/mason.nvim) for adapter binaries

## Installation

### lazy.nvim

```lua
{
  "StefanBartl/dap.nvim",
  dependencies = {
    "StefanBartl/lib.nvim",
    "mfussenegger/nvim-dap",
    "igorlfs/nvim-dap-view",      -- default panel UI
    -- "rcarriga/nvim-dap-ui",    -- opt-in alternative (ui.provider = "dap-ui")
    -- "nvim-neotest/nvim-nio",   -- required by nvim-dap-ui
    "theHamsta/nvim-dap-virtual-text", -- optional
    "jbyuki/one-small-step-for-vimkind", -- optional, Lua debugging
  },
  event = "VeryLazy",
  opts = {},
}
```

### packer.nvim

```lua
use({
  "StefanBartl/dap.nvim",
  requires = {
    "StefanBartl/lib.nvim",
    "mfussenegger/nvim-dap",
    "igorlfs/nvim-dap-view",
    "theHamsta/nvim-dap-virtual-text",
    "jbyuki/one-small-step-for-vimkind",
  },
  config = function()
    require("dap_nvim").setup({})
  end,
})
```

### Adapter Installation

Via Mason:

```vim
:MasonInstall js-debug-adapter codelldb delve debugpy
```

Manual:
- **Delve (Go):** `go install github.com/go-delve/delve/cmd/dlv@latest`
- **debugpy (Python):** `pip install debugpy`
- **CodeLLDB:** download from [GitHub Releases](https://github.com/vadimcn/codelldb/releases)

## Configuration

Full defaults:

```lua
require("dap_nvim").setup({
  languages = {},  -- empty = all available

  ui = {
    enable = true,             -- wire a panel UI at all
    provider = "dap-view",     -- "dap-view" | "dap-ui" | "auto" | "none"
    -- dap_view = {},          -- optional, passed to dap-view's setup()
    -- dap_ui = {},            -- optional, passed to dapui's setup()
    virtual_text = true,  -- nvim-dap-virtual-text
    signs = true,          -- gutter signs
    highlights = true,     -- default highlight groups
  },

  keymaps = {
    enable = true,
    prefix = "<leader>d",
  },

  which_key = {
    enable = true,   -- group label for the keymaps prefix
  },

  autocmds = {
    enable = true,   -- cursorline toggle while DAP UI is open
  },

  -- Custom adapter overrides, keyed by language (merged by each adapter module)
  adapters = {},

  -- Custom launch configurations, keyed by language (appended to defaults)
  configurations = {
    go = {
      { type = "go", name = "Debug Package", request = "launch", program = "${fileDirname}" },
    },
  },

  auto_install = false,           -- reserved: Mason auto-install
  log_level = vim.log.levels.WARN,
})
```

Every key is independently overridable — set only what you want to change.

## Panel UI

dap.nvim wires **exactly one** panel UI. Running nvim-dap-view and nvim-dap-ui
side by side means two competing window layouts and two sets of auto-open/close
listeners on the same nvim-dap events, so `ui.provider` picks one:

| `ui.provider` | Behaviour |
| --- | --- |
| `"dap-view"` | **Default.** Wire [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view) — lighter, single-window, no nvim-nio dependency |
| `"dap-ui"` | Wire [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) with the layout from `config.dapui_layout` (or your `ui.dap_ui` table) |
| `"auto"` | First of the two that is installed, nvim-dap-view winning |
| `"none"` | No panel UI; signs, highlights and virtual text still apply |

If the preferred provider is not installed but the other one is, dap.nvim falls
back to it and warns once. `ui.enable = false` disables the panel UI entirely,
regardless of `provider`.

Both providers open on `event_initialized` and close when the session
terminates or exits. `<leader>du` / `:DapToggleUI` and `<leader>de` / `:DapEval`
route through the active provider, so the bindings do not change when you
switch. One behavioural difference: nvim-dap-ui's eval opens a floating window,
while nvim-dap-view has no float and instead adds the expression to its watch
list.

To go back to nvim-dap-ui:

```lua
opts = {
  ui = { provider = "dap-ui" },
}
```

`:checkhealth dap_nvim` reports both the configured preference and the provider
that actually got wired.

## Default Keymaps

See [docs/BINDINGS.md](docs/BINDINGS.md) for the full cheatsheet. Quick
reference (prefix defaults to `<leader>d`):

| lhs | desc |
| --- | --- |
| `<leader>dc` | Continue |
| `<leader>db` | Toggle Breakpoint |
| `<leader>ds` / `di` / `do` | Step Over / Into / Out |
| `<leader>du` | Toggle UI |
| `<leader>de` | Evaluate Expression (normal + visual) |

Disable everything with `keymaps = { enable = false }`, or just change
`keymaps.prefix`.

## User Commands

`:DapContinue`, `:DapStepOver`, `:DapStepInto`, `:DapStepOut`,
`:DapTerminate`, `:DapRestart`, `:DapToggleBreakpoint`,
`:DapListBreakpoints`, `:DapToggleUI`, `:DapEval` — always registered,
independent of `keymaps.enable`. Full list in
[docs/BINDINGS.md](docs/BINDINGS.md).

## Health Check

```vim
:checkhealth dap_nvim
```

Verifies Neovim version, nvim-dap presence, lib.nvim modules, optional UI
companions (the configured and active panel UI, nvim-dap-virtual-text,
which-key), and per-language
adapter availability (binary on `$PATH` or via Mason).

## Architecture

```
docs/BINDINGS.md              Cheatsheet: every keymap, user command, autocmd
plugin/dap.lua                 Load guard (vim.g.loaded_dap_nvim)
lua/dap_nvim/
  init.lua                     setup() — orchestrates core/adapters/configurations/ui/bindings
  @types/init.lua               LuaLS type definitions (Dap.Config, ...)
  registry.lua                  Language adapter registry with validation
  health.lua                    :checkhealth dap_nvim
  config/
    DEFAULTS.lua                Immutable defaults
    init.lua                    Merge + access to active config, adapter/binary metadata
  core/
    init.lua / setup.lua         nvim-dap presence check, capability detection, state init
    state.lua                   Minimal session state
    capabilities.lua            Soft-dependency detection (dap-view, dapui, virtual-text)
  adapters/                     dap.adapters.* registration, one file per language
  configurations/                dap.configurations.* launch configs, one file per language
  ui/                           signs, highlights, panel UI provider, nvim-dap-virtual-text
    provider.lua                Resolves + dispatches to the active panel UI
    dapview.lua                 nvim-dap-view wiring (default)
    dapui.lua                   nvim-dap-ui wiring (opt-in)
  bindings/                     Every user-facing trigger — registration only
    init.lua                    orchestrates usercmds/keymaps/which_key/autocmds
    usercmds.lua                 registers all :Dap* user commands
    keymaps.lua                  default keymaps under the configurable prefix
    which_key.lua                 optional which-key group label
    autocmds.lua                  DAP UI cursorline toggle
  utils/                        notify, executable/Mason path resolution, path helpers, validation
```

lib.nvim provides notify, `cross` (platform detection, Mason `.cmd` fallback
on Windows), and `normalize` (Windows-safe path normalization).
