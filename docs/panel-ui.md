# Panel UI

dap.nvim wires **exactly one** panel UI. Running nvim-dap-view and nvim-dap-ui
side by side means two competing window layouts and two sets of auto-open/close
listeners on the same nvim-dap events, so `ui.provider` picks one:

| `ui.provider` | Behaviour |
| --- | --- |
| `"dap-view"` | **Default.** Wire [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view) — lighter, single-window, no nvim-nio dependency |
| `"dap-ui"` | Wire [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) with the layout from `config.dapui_layout` (or your `ui.dap_ui` table) |
| `"auto"` | First of the two that is installed, nvim-dap-view winning |
| `"none"` | No panel UI; signs, highlights and virtual text still apply |

If the preferred provider is not installed but the other one is, dap.nvim falls
back to it and warns once. `ui.enable = false` disables the panel UI entirely,
regardless of `provider`.

Both providers open on `event_initialized` and close when the session
terminates or exits. `<leader>du` / `:Dap toggle-ui` and `<leader>de` / `:Dap eval`
route through the active provider, so the bindings do not change when you
switch. One behavioural difference: nvim-dap-ui's eval opens a floating window,
while nvim-dap-view has no float and instead adds the expression to its watch
list.

To go back to nvim-dap-ui:

```lua
opts = {
  ui = { provider = "dap-ui" },
}
```

`:checkhealth wkddap` reports both the configured preference and the provider
that actually got wired.
