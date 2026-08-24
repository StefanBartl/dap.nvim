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

Registers through `lib.nvim.map`. (This used to be a `pcall` fallback to
`vim.keymap.set` with a note that `lib.nvim.map` "doesn't ship yet" — it
does, so the fallback and the note are gone.)
`keymaps.setup()` requires `nvim-dap` eagerly to bind its functions directly;
that call is wrapped in `pcall` so a missing nvim-dap only skips keymaps
instead of aborting the rest of `setup()`.

## Counted step chaining

- **Tab:** true
- **Module:** `lua/wkddap/bindings/keymaps/init.lua` (`counted_step`), on
  top of `lib.nvim.count.chain`
- **Keymaps:** `<leader>ds` / `<leader>di` / `<leader>do`

Step Over/Into/Out honor `vim.v.count1`, so `5<leader>ds` steps over five
times — but the DAP spec forbids firing a new step request while the thread
is still running from a previous one, so a naive `for i=1,count do fn() end`
would desync from the adapter's actual state.

Instead, a count > 1 registers a listener on
`dap.listeners.after.event_stopped`: the first step fires immediately, and
each subsequent one only fires after the adapter confirms (via the DAP
`stopped` event) that the previous step actually landed. The chain is capped
at 1000 so a mistyped count can't queue an unbounded sequence, and listeners
are torn down on `event_terminated`/`event_exited` so a session ending
mid-chain doesn't leave a dangling listener waiting for a stop event that
will never come.

With no count (the common case) this calls the step function directly and
registers no listener at all — zero overhead over calling `dap.step_over()`
straight.

**The chaining itself moved to `lib.nvim.count.chain` (2026-08-24)**, having
been generalized out of the version that used to live here — the cap, the
teardown, the no-count fast path and the refusal to advance after an abort
are its behavior now. What stays in this plugin is the only DAP-specific
part: which events mean "the previous one finished" and "the thing being
driven went away". The pattern was worth hoisting because it is not really
about debugging — anything whose completion arrives as an event rather than
a return has the same problem.

## Pre-filled breakpoint prompts

- **Tab:** true
- **Module:** `lua/wkddap/core/breakpoints.lua` (`prompt_condition`,
  `prompt_log_point`, `forget`)
- **Keymaps:** `<leader>dB` (condition), `<leader>dL` (log point)
- **Usercmds:** `:Dap conditional-breakpoint`, `:Dap log-point` (the
  no-argument form; passing the value inline skips the prompt entirely)
- **Also:** the nvzone/menu entries in `integrations/menu.lua`

The prompt used to open empty every time, so fixing a typo in a condition — or
putting the same condition on the next line — meant retyping the whole thing.
It now opens pre-filled, in this order of preference:

1. **The value already on a breakpoint at this line.** The edit case, and the
   one that matters most: `<leader>dB` on a line that already has a
   conditional breakpoint now shows that condition instead of pretending
   there is none. Read from `dap.breakpoints.get(bufnr)`.
2. **The last value submitted this session.** The reuse case.
3. Empty.

Conditions and log messages are remembered separately, so the two prompts
never pre-fill each other. The memory is session state on purpose: a
condition is about the run you are doing now, and persisting it across
restarts would resurrect a stale one at the worst moment. `M.forget()` clears
it without a restart.

Submitting an **empty** line stays meaningful rather than being treated as a
cancel — nvim-dap reads an empty condition as "no condition", so clearing the
prompt and pressing `<CR>` turns a conditional breakpoint back into a plain
one. `<Esc>` cancels outright and changes nothing.

Added 2026-08-24, closing the flag/option audit's entry ("no way to reuse or
edit a previous breakpoint condition/log point message — the prompt is always
empty"). The three call sites that each had their own copy of the empty
prompt now share this module.

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

## Right-click context menu (nvzone/menu)

`wkddap.integrations.menu` contributes entries for session control
(Continue/Step Over/Step Into/Step Out/Terminate/Restart), breakpoints
(Toggle/Conditional/Log Point/List), and the panel UI (Toggle DAP UI,
Evaluate Expression/Selection) — the same actions the default keymaps
expose, in the shape [nvzone/menu](https://github.com/nvzone/menu) expects.
dap.nvim has no dependency on `menu` and never opens a context menu itself
— a host (typically your own `<RightMouse>` dispatcher) composes the
entries into its own menu. `items()` degrades to an empty list when
nvim-dap isn't installed, same as every other entry point here.

- **Module:** `lua/wkddap/integrations/menu.lua` (`M.items`, `M.submenu`)
- **Config:** `opts.menu.enable` (default `true`)
