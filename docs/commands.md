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
| `<leader>dm` | Memory View (hex/bits, editable — [FEATURES/MEMORY.md](FEATURES/MEMORY.md)) |

Disable everything with `keymaps = { enable = false }`, or just change
`keymaps.prefix`.

## User Commands

One command, `:Dap <subcommand>` (built via
[`lib.nvim.bindings.usercmd.composer`](https://github.com/WKDSteve/lib.nvim), with
`<Tab>` completion): `continue`, `step-over`, `step-into`, `step-out`,
`terminate`, `restart`, `toggle-breakpoint`, `conditional-breakpoint`,
`log-point`, `list-breakpoints`, `toggle-ui`, `eval`, `repl`, `memory` — always
registered, independent of `keymaps.enable`. Full list in
[docs/BINDINGS.md](BINDINGS.md).

`:Dap memory [address-or-expression]` opens the memory view of the running
session (`:Dap memory &buffer`, `:Dap memory 0x404010`; prompts without an
argument). It needs an adapter that supports `readMemory` (and `writeMemory`
for edits) — GDB's `gdb -i dap` does. See
[FEATURES/MEMORY.md](FEATURES/MEMORY.md).
