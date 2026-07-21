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
commands, and a which-key group label. Built on
[lib.nvim](https://github.com/StefanBartl/lib.nvim) as a deliberate shared
dependency.

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
:checkhealth dap
```

## Documentation

- [Features](docs/features.md) — supported languages, adapters, and filetype aliases.
- [Installation](docs/installation.md) — requirements, lazy.nvim/packer.nvim setup, and adapter binary installation.
- [Configuration](docs/configuration.md) — full `setup()` options and their defaults.
- [Panel UI](docs/panel-ui.md) — choosing between nvim-dap-view and nvim-dap-ui via `ui.provider`.
- [Commands and Keymaps](docs/commands.md) — quick reference for default keymaps and `:Dap*` user commands.
- [docs/BINDINGS.md](docs/BINDINGS.md) — full cheatsheet of every keymap, user command, and autocommand.
- [Health Check](docs/health.md) — what `:checkhealth dap` verifies.
- [Architecture](docs/architecture.md) — module layout and file responsibilities.
- [docs/ROADMAP.md](docs/ROADMAP.md) — implemented features and planned work.
