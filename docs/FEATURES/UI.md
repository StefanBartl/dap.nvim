# UI

Everything that draws or wires visual state around a debug session:
breakpoint/stopped-line signs, highlight groups, the panel UI itself, and
inline variable values.

## Panel UI provider abstraction

- **Tab:** true
- **Module:** `lua/wkddap/ui/provider.lua` (`setup`, `active`, `toggle`,
  `eval`), `lua/wkddap/ui/dapview.lua`, `lua/wkddap/ui/dapui.lua`
- **Config:** `opts.ui.provider` (`"dap-view"` | `"dap-ui"` | `"auto"` |
  `"none"`, default `"dap-view"`), `opts.ui.enable`
- **Keymaps:** [../BINDINGS.md#default-keymaps](../BINDINGS.md#default-keymaps)
  (`<leader>du`, `<leader>de`)
- **Usercmds:** [../BINDINGS.md#user-commands](../BINDINGS.md#user-commands)
  (`:Dap toggle-ui`, `:Dap eval`)

dap.nvim wires **exactly one** panel UI — running nvim-dap-view and
nvim-dap-ui side by side would mean two competing window layouts and two sets
of auto-open/close listeners on the same nvim-dap events.

### Resolution

- `"dap-view"` / `"dap-ui"` — wire that one; if it isn't installed but the
  other is, fall back to the other and warn once.
- `"auto"` — first installed of the two, nvim-dap-view winning ties.
- `"none"` — no panel UI; signs, highlights, and virtual text still apply.

### What routes through it

Both providers open on the `event_initialized` nvim-dap listener and close on
`event_terminated`/`event_exited`, so `<leader>du` / `:Dap toggle-ui` and
`<leader>de` / `:Dap eval` behave the same regardless of which is active —
callers never hardcode either plugin. One real behavioural difference stays
visible to the user: nvim-dap-ui's `eval()` opens a floating window, while
nvim-dap-view has no float and instead adds the expression to its watch list.

`:checkhealth wkddap` reports both the configured preference and the
provider that actually got wired, flagging a mismatch.

## Breakpoint & stopped-line signs

Defines the gutter signs nvim-dap uses for breakpoints, conditional
breakpoints, rejected breakpoints, log points, and the current stopped line.

- **Module:** `lua/wkddap/ui/signs.lua` (`setup`), `lua/wkddap/config/init.lua`
  (`M.signs`)
- **Config:** `opts.ui.signs` (default `true`)

## Highlight groups

Applies default colors for the sign set above (`DapBreakpoint`,
`DapBreakpointCondition`, `DapBreakpointRejected`, `DapLogPoint`,
`DapStopped`, `DapStoppedLine`) via `nvim_set_hl`.

- **Module:** `lua/wkddap/ui/highlights.lua` (`setup`), `lua/wkddap/config/init.lua`
  (`M.highlights`)
- **Config:** `opts.ui.highlights` (default `true`)

## nvim-dap-virtual-text integration

Soft dependency: wires `nvim-dap-virtual-text` with a fixed default config
(commented variables shown, changed-variable highlighting, stop-reason text)
if the plugin is installed; a no-op otherwise.

- **Module:** `lua/wkddap/ui/virtual_text.lua` (`setup`), `lua/wkddap/config/init.lua`
  (`M.virtual_text`)
- **Config:** `opts.ui.virtual_text` (default `true`)
