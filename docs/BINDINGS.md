# dap.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
defined by `dap.nvim`. This file is documentation only and mirrors the
source of truth:

- keymaps   — `lua/dap/bindings/keymaps.lua`
- commands  — `lua/dap/bindings/usercmds.lua`
- autocmds  — `lua/dap/bindings/autocmds.lua`
- which-key — `lua/dap/bindings/which_key.lua`

Any change there must be reflected here.

## Default Keymaps

Normal/visual-mode keymaps installed by `bindings.setup()`, gated by
`config.keymaps.enable`. The prefix defaults to `<leader>d`
(`config.keymaps.prefix`).

| lhs | mode | desc |
| --- | --- | --- |
| `<leader>dc` | n | Continue |
| `<leader>ds` | n | Step Over |
| `<leader>di` | n | Step Into |
| `<leader>do` | n | Step Out |
| `<leader>dt` | n | Terminate |
| `<leader>dr` | n | Restart |
| `<leader>db` | n | Toggle Breakpoint |
| `<leader>dB` | n | Conditional Breakpoint (prompts for condition) |
| `<leader>dL` | n | Log Point (prompts for log message) |
| `<leader>dl` | n | List Breakpoints |
| `<leader>du` | n | Toggle UI (active panel UI provider) |
| `<leader>de` | n, v | Evaluate Expression / Selection (dap-ui: float, dap-view: watch) |
| `<leader>dR` | n | Open REPL |

which-key gets a single group label for the prefix
(`config.which_key.enable`); individual keys already carry their own `desc`.

## User Commands

One command, `:Dap <subcommand>` (built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim), with
`<Tab>` completion). Always registered, independent of `keymaps.enable`.

| command | desc |
| --- | --- |
| `:Dap continue` | Continue |
| `:Dap step-over` | Step Over |
| `:Dap step-into` | Step Into |
| `:Dap step-out` | Step Out |
| `:Dap terminate` | Terminate |
| `:Dap restart` | Restart |
| `:Dap toggle-breakpoint` | Toggle Breakpoint |
| `:Dap list-breakpoints` | List Breakpoints |
| `:Dap toggle-ui` | Toggle UI (active panel UI provider) |
| `:Dap eval` | Evaluate Expression (dap-ui: float, dap-view: watch) |

## Autocommands

Registered by `bindings.autocmds.setup()` into the `DapNvimAuto` augroup,
gated by `config.autocmds.enable`.

| event | group | pattern | desc |
| --- | --- | --- | --- |
| `User` | `DapNvimAuto` | `DapUIWindowOpen` | Enable `cursorline` while the DAP UI is open |
| `User` | `DapNvimAuto` | `DapUIWindowClose` | Disable `cursorline` when the DAP UI closes |
