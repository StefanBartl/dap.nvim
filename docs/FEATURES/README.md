# Features

`dap.nvim` is a configuration layer on top of
[nvim-dap](https://github.com/mfussenegger/nvim-dap): it registers adapters
and launch configurations for eleven languages, detects and validates adapter
binaries (with Mason fallback), wires exactly one panel UI, and ships
user-configurable keymaps, commands, and health checks. It does not replace
nvim-dap or talk DAP itself — everything here is setup and glue around it.

Organized by theme:

- [LANGUAGES.md](LANGUAGES.md) — per-language adapters and launch configs,
  adapter detection, Mason integration, custom overrides, aliases.
- [UI.md](UI.md) — the panel UI provider abstraction, signs, highlights,
  virtual text.
- [CONTROLS.md](CONTROLS.md) — keymaps, the `:Dap` user command, which-key,
  autocmds.
- [HEALTH.md](HEALTH.md) — `:checkhealth wkddap`.
