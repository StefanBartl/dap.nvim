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

---

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
> dependencies — see [Requirements](docs/requirements.md).

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

**The Basics**

- [Requirements](docs/requirements.md) — Neovim version, required plugins and adapter binaries.
- [Installation](docs/installation.md) — every plugin manager, and per-language adapter installation.
- [Quickstart](docs/quickstart.md) — the first thing to run after installing.

**Configuration**

- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Commands and keymaps](docs/commands.md) — the default keys and the `:Dap` subcommands.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand at a glance.

**The Rest**

- [Features](docs/FEATURES/README.md) — languages, adapters, panel UI, controls, health checks.
- [Panel UI](docs/panel-ui.md) — choosing between nvim-dap-view and nvim-dap-ui via `ui.provider`.
- [Workflow](docs/WORKFLOW.md) — how the pieces combine in daily debugging use, with the gotchas.
- [Integrations](docs/integrations.md) — the nvzone/menu context-menu bridge.
- [Health check](docs/health.md) — what `:checkhealth wkddap` verifies.
- [Architecture](docs/architecture.md) — module layout and file responsibilities.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add a language.
- [Feedback](https://github.com/StefanBartl/dap.nvim/issues)

`:help wkddap` is the same reference inside the editor.

---

## License

MIT — see [LICENSE](LICENSE).
