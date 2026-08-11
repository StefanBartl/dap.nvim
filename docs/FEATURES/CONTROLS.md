# Controls

Every user-facing trigger — keymaps, the `:Dap` user command, which-key
integration, and the one autocmd pair dap.nvim registers itself. Full
reference table: [../BINDINGS.md](../BINDINGS.md).

## Default keymaps under a configurable prefix

All keymaps live under a single prefix (default `<leader>d`) and are only
installed when `keymaps.enable` is true. Every mapping carries its own
`desc`, so which-key needs nothing beyond a group label.

- **Module:** `lua/wkddap/bindings/keymaps/init.lua` (`setup`)
- **Config:** `opts.keymaps.enable` (default `true`), `opts.keymaps.prefix`
  (default `<leader>d`)
- **Keymaps:** [../BINDINGS.md#default-keymaps](../BINDINGS.md#default-keymaps)

Uses `lib.nvim.map` if present, falling back to `vim.keymap.set` directly —
`lib.nvim.map` doesn't ship yet, so this degrades to the plain Neovim API
today and will pick up the shared helper automatically once it lands.
`keymaps.setup()` requires `nvim-dap` eagerly to bind its functions directly;
that call is wrapped in `pcall` so a missing nvim-dap only skips keymaps
instead of aborting the rest of `setup()`.

## Counted step chaining

- **Tab:** true
- **Module:** `lua/wkddap/bindings/keymaps/init.lua` (`counted_step`)
- **Keymaps:** `<leader>ds` / `<leader>di` / `<leader>do`

Step Over/Into/Out honor `vim.v.count1`, so `5<leader>ds` steps over five
times — but the DAP spec forbids firing a new step request while the thread
is still running from a previous one, so a naive `for i=1,count do fn() end`
would desync from the adapter's actual state.

Instead, a count > 1 registers a one-shot listener on
`dap.listeners.after.event_stopped`: the first step fires immediately, and
each subsequent one only fires after the adapter confirms (via the DAP
`stopped` event) that the previous step actually landed. The chain is capped
at `MAX_CHAINED_STEPS = 1000` so a mistyped count can't queue an unbounded
sequence, and listeners are torn down on `event_terminated`/`event_exited` so
a session ending mid-chain doesn't leave a dangling listener waiting for a
stop event that will never come.

With no count (the common case) this calls the step function directly and
registers no listener at all — zero overhead over calling `dap.step_over()`
straight.

## `:Dap` user command

One command with `<Tab>`-completed subcommands, built via
`lib.nvim.usercmd.composer`. Every default keymap has a 1:1 `:Dap`
equivalent, and the command is always registered — independent of
`keymaps.enable`, so it works even with keymaps disabled.

- **Module:** `lua/wkddap/bindings/usercmds/init.lua` (`setup`)
- **Usercmds:** [../BINDINGS.md#user-commands](../BINDINGS.md#user-commands)

## Conditional breakpoints & log points

`:Dap conditional-breakpoint [condition]` and `:Dap log-point [message]`
(and their `<leader>dB` / `<leader>dL` keymap equivalents) take the value
directly as an argument, or prompt for it interactively via `lib.nvim.ui.kit`
when omitted.

- **Module:** `lua/wkddap/bindings/usercmds/init.lua`,
  `lua/wkddap/bindings/keymaps/init.lua`

The JS/TS "Attach" launch config's process picker
(`lua/wkddap/utils/validation.lua`'s `pick_process`) uses the same
coroutine-based prompt pattern, listing `ps -eo pid,comm` output.

## which-key group label

Registers a single group label (`"DAP"`) for the keymap prefix if
which-key is installed; a no-op otherwise. Supports both the which-key v3
(`add`) and v2 (`register`) APIs.

- **Module:** `lua/wkddap/bindings/which_key/init.lua` (`setup`, `available`)
- **Config:** `opts.which_key.enable` (default `true`)

## Cursorline toggle autocmd

Toggles `cursorline` in the current window while the DAP panel UI is open.

- **Module:** `lua/wkddap/bindings/autocmds/init.lua` (`setup`)
- **Config:** `opts.autocmds.enable` (default `true`)
- **Autocmds:** [../BINDINGS.md#autocommands](../BINDINGS.md#autocommands)

Listens for the `DapUIWindowOpen`/`DapUIWindowClose` `User` events, which
only **nvim-dap-ui** emits — see [UI.md](UI.md)'s panel UI provider entry.
With the default `dap-view` provider active, this autocmd pair is wired but
never fires.
