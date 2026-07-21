# Architecture

```
docs/BINDINGS.md              Cheatsheet: every keymap, user command, autocmd
plugin/dap.lua                 Load guard (vim.g.loaded_dap)
lua/dap/
  init.lua                     setup() — orchestrates core/adapters/configurations/ui/bindings
  @types/init.lua               LuaLS type definitions (Dap.Config, ...)
  registry.lua                  Language adapter registry with validation
  health.lua                    :checkhealth dap
  config/
    DEFAULTS.lua                Immutable defaults
    init.lua                    Merge + access to active config, adapter/binary metadata
  core/
    init.lua / setup.lua         nvim-dap presence check, capability detection, state init
    state.lua                   Minimal session state
    capabilities.lua            Soft-dependency detection (dap-view, dapui, virtual-text)
  adapters/                     dap.adapters.* registration, one file per language
  configurations/                dap.configurations.* launch configs, one file per language
  ui/                           signs, highlights, panel UI provider, nvim-dap-virtual-text
    provider.lua                Resolves + dispatches to the active panel UI
    dapview.lua                 nvim-dap-view wiring (default)
    dapui.lua                   nvim-dap-ui wiring (opt-in)
  bindings/                     Every user-facing trigger — registration only
    init.lua                    orchestrates usercmds/keymaps/which_key/autocmds
    usercmds.lua                 registers all :Dap* user commands
    keymaps.lua                  default keymaps under the configurable prefix
    which_key.lua                 optional which-key group label
    autocmds.lua                  DAP UI cursorline toggle
  utils/                        notify, executable/Mason path resolution, path helpers, validation
```

lib.nvim provides notify, `cross` (platform detection, Mason `.cmd` fallback
on Windows), and `normalize` (Windows-safe path normalization).
