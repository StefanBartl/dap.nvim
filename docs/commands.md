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

One command, `:Dap <subcommand>` (built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim), with
`<Tab>` completion): `continue`, `step-over`, `step-into`, `step-out`,
`terminate`, `restart`, `toggle-breakpoint`, `list-breakpoints`, `toggle-ui`,
`eval` — always registered, independent of `keymaps.enable`. Full list in
[docs/BINDINGS.md](BINDINGS.md).
