# Commands and Keymaps

See [docs/BINDINGS.md](BINDINGS.md) for the full cheatsheet (every keymap,
user command, and autocommand). Quick reference below (prefix defaults to
`<leader>d`):

## Default Keymaps

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
[docs/BINDINGS.md](BINDINGS.md).
