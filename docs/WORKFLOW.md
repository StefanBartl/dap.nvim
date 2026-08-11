# Workflow — getting real use out of dap.nvim day to day

Every feature here is documented on its own elsewhere
([FEATURES/](FEATURES/README.md), [BINDINGS.md](BINDINGS.md)). This is the
different question: once a debug session is actually running, how do the
pieces combine, and where does this particular config layer surprise you.

## Before the first session: `:checkhealth wkddap`, not trial and error

Run `:checkhealth wkddap` once per machine/project, before you ever try
`<leader>dc`. It tells you, in order: whether nvim-dap itself is installed
(the one truly required dependency — dap.nvim configures it, it does not
replace it), which panel UI is configured vs. actually active (a mismatch
here means your `ui.provider` preference silently fell back — see below),
per-language adapter availability resolved through the same alias table
registration uses, and any `registry.validate()` errors for languages you
already enabled. Chasing "why didn't my breakpoint fire" without checking
this first usually means chasing the wrong thing — a missing adapter binary
looks identical to a broken breakpoint from the editor's side.

## The debugging loop: continue, step, evaluate

`<leader>dc` (`:Dap continue`) starts or resumes. `<leader>db` toggles a
plain breakpoint at the cursor line; `<leader>dB` / `<leader>dL` prompt for a
condition or log message (or take one directly: `:Dap conditional-breakpoint
i > 10`). `<leader>ds`/`di`/`do` step over/into/out — and take a count:
`5<leader>ds` steps over five times, safely, by waiting for the adapter to
confirm each step landed before firing the next one (see "Counted steps" in
[FEATURES/CONTROLS.md](FEATURES/CONTROLS.md) for why a naive loop would be
wrong here). `<leader>de` evaluates the expression under the cursor (normal
mode) or the visual selection — what actually happens next depends on which
panel UI is active, which is the first real gotcha below.

Every one of these has a `:Dap <subcommand>` equivalent, always registered
regardless of `keymaps.enable` — useful for scripting a debug session from a
command, or when you've turned keymaps off but still want `:Dap continue`
from the command line.

## `ui.provider`: pick one, and know what changes when you switch

dap.nvim wires **exactly one** panel UI. The comparison that actually matters
day to day:

| | `dap-view` (default) | `dap-ui` |
|---|---|---|
| Window layout | Single window | Multi-panel (`config.dapui_layout`) |
| `<leader>de` / `:Dap eval` | Adds expression to the watch list | Opens a floating window |
| Cursorline-toggle autocmd | Never fires (see below) | Fires on open/close |
| Extra dependency | None | `nvim-neotest/nvim-nio` |

Switching is one option: `opts = { ui = { provider = "dap-ui" } }`. If the
plugin for your preference isn't installed but the other one is, dap.nvim
falls back silently at the config level but **warns once** and
`:checkhealth wkddap` will show the mismatch persistently — worth checking
after a `provider` change, not just after install.

**Gotcha: the cursorline-autocmd feature is a no-op with the default
provider.** `bindings/autocmds/init.lua` toggles `cursorline` on the
`DapUIWindowOpen`/`DapUIWindowClose` `User` events — but only **nvim-dap-ui**
ever emits those events. With `dap-view` (the default `ui.provider`), this
autocmd pair is registered, `autocmds.enable` shows as on, and it simply
never fires. If you rely on this, you need `ui.provider = "dap-ui"`.

## Setting up a new language: don't fight the module, override it

Each language module (`lua/wkddap/languages/<lang>.lua`) ships a small,
opinionated set of launch configs. Don't edit the plugin's files to add your
own — `opts.configurations` appends to the built-ins per language by default:

```lua
opts = {
  configurations = {
    go = {
      { type = "go", name = "Debug with args", request = "launch",
        program = "${fileDirname}", args = { "--verbose" } },
    },
  },
}
```

Add `replace = true` alongside the entries in that language's table to
discard the built-ins entirely instead of appending — useful for Python,
where the single built-in "Launch file" config rarely matches a real
project's entry point.

## Gotchas worth knowing before you hit them

**Rust pretty-printers degrade silently, not loudly.** The Rust launch
config's `initCommands` shells out to `rustc --print sysroot` and then reads
`<sysroot>/lib/rustlib/etc/lldb_commands` with a plain `io.open`. If `rustc`
isn't on `$PATH`, or that file doesn't exist for the installed toolchain,
`io.open` just returns `nil` — the loop over its lines is skipped, and you
get a session with `command script import` but no pretty printers, no error
message at all. If Rust structs display as raw memory instead of readable
values, check `rustc --print sysroot` from a shell first.

**Zig's "build first" config runs `zig build` synchronously.** The second
Zig launch config (`Launch (build first)`) calls
`vim.system({ "zig", "build" }):wait()` before prompting for the executable
path — `:wait()` blocks the whole config resolution, and by extension the
editor, until the build finishes. A slow build is a genuinely frozen Neovim
until it's done, not a background task with a spinner.

**The JS/TS adapter path is hardcoded to Mason's install location, not to
whatever `js-debug-adapter` resolved to.** `config.get_adapter_path` is only
used to *gate* whether the JS adapter registers at all (PATH, then Mason
bin); the actual server it launches
(`dap.adapters["pwa-node"]`) always points at
`stdpath("data")/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js`
regardless. A manually-installed `js-debug-adapter` that isn't under Mason's
package directory will pass the presence check and then fail to actually
launch — install this one via Mason (`:MasonInstall js-debug-adapter`), not
manually.

**`auto_install` needs `mason.nvim` present already.** `opts.auto_install =
true` does not install Mason itself — if `mason.nvim` isn't installed, it
warns and does nothing. It's an accelerator for "these are already-known
Mason packages," not a bootstrapper.

**`setup()` only runs once.** Calling `require("wkddap").setup()` a second
time in the same session is a no-op with a warning
(`M._initialized`) — there's no supported way to hot-reload configuration
changes short of restarting Neovim. Worth remembering while iterating on
`opts` in a config file: `:source %` on the config won't re-apply anything.

**Cancelling a prompt must always resume, or the launch hangs.** Conditional
breakpoints, log points, and the JS/TS process picker all suspend the
launch-config coroutine with `coroutine.yield()` while `lib.nvim.ui.kit`
shows a prompt. This is transparent in normal use (`<Esc>` cancels cleanly),
but it's why every prompt in this codebase wires `on_cancel` as carefully as
`on_submit` — a picker that could dismiss without resuming the coroutine
would leave the debug session launch hanging indefinitely instead of just
failing.

## Windows note: Mason binaries need the `.cmd` suffix, and dap.nvim handles it — once

`get_adapter_path`'s Mason-fallback branch appends `.cmd` to the binary name
on Windows before checking `mason/bin/`. This only matters if you're
troubleshooting adapter resolution manually (e.g. checking
`stdpath("data") .. "/mason/bin/dlv"` by hand on Windows and wondering why it
doesn't exist) — the real file is `dlv.cmd`, and dap.nvim already accounts
for that; you don't need to.
