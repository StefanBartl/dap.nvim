# dap.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
defined by `dap.nvim`. This file is documentation only and mirrors the
source of truth:

- keymaps   — `lua/wkddap/bindings/keymaps/init.lua`
- commands  — `lua/wkddap/bindings/usercmds/init.lua`
- autocmds  — `lua/wkddap/bindings/autocmds/init.lua`
- which-key — `lua/wkddap/bindings/which_key/init.lua`

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
| `<leader>dB` | n | Conditional Breakpoint (prompts, pre-filled — see below) |
| `<leader>dL` | n | Log Point (prompts, pre-filled — see below) |
| `<leader>dl` | n | List Breakpoints |
| `<leader>du` | n | Toggle UI (active panel UI provider) |
| `<leader>de` | n, v | Evaluate Expression / Selection (dap-ui: float, dap-view: watch) |
| `<leader>dR` | n | Open REPL |

`<leader>dB` and `<leader>dL` (and the no-argument `:Dap
conditional-breakpoint` / `:Dap log-point`) open pre-filled: with this line's
existing condition/log message if it has one, otherwise with the last one you
submitted this session. Submitting an empty line clears the value — that is
how you turn a conditional breakpoint back into a plain one — while `<Esc>`
cancels and changes nothing. See
[FEATURES/CONTROLS.md](FEATURES/CONTROLS.md#pre-filled-breakpoint-prompts).

which-key gets a single group label for the prefix
(`config.which_key.enable`); individual keys already carry their own `desc`.

## User Commands

One command, `:Dap <subcommand>` (built via
[`lib.nvim.bindings.usercmd.composer`](https://github.com/StefanBartl/lib.nvim), with
`<Tab>` completion). Always registered, independent of `keymaps.enable`.
Every default keymap has a 1:1 `:Dap` equivalent.

| command | desc |
| --- | --- |
| `:Dap continue` | Continue |
| `:Dap step-over` | Step Over |
| `:Dap step-into` | Step Into |
| `:Dap step-out` | Step Out |
| `:Dap terminate` | Terminate |
| `:Dap restart` | Restart |
| `:Dap toggle-breakpoint` | Toggle Breakpoint |
| `:Dap conditional-breakpoint [condition]` | Conditional Breakpoint (prompts if `condition` omitted) |
| `:Dap log-point [message]` | Log Point (prompts if `message` omitted) |
| `:Dap list-breakpoints` | List Breakpoints |
| `:Dap toggle-ui` | Toggle UI (active panel UI provider) |
| `:Dap eval` | Evaluate Expression (dap-ui: float, dap-view: watch) |
| `:Dap repl` | Open REPL |

## Autocommands

Registered by `bindings.autocmds.setup()` into the `DapNvimAuto` augroup,
gated by `config.autocmds.enable`.

| event | group | pattern | desc |
| --- | --- | --- | --- |
| `User` | `DapNvimAuto` | `DapUIWindowOpen` | Enable `cursorline` while the DAP UI is open |
| `User` | `DapNvimAuto` | `DapUIWindowClose` | Disable `cursorline` when the DAP UI closes |
