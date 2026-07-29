# Architecture

```
docs/BINDINGS.md              Cheatsheet: every keymap, user command, autocmd
plugin/dap.lua                 Load guard (vim.g.loaded_wkddap)
lua/wkddap/
  init.lua                     setup() — orchestrates core/adapters/configurations/ui/bindings
  @types/init.lua               LuaLS type definitions (Dap.Config, ...)
  registry.lua                  Language adapter registry with validation
  health.lua                    :checkhealth wkddap
  config/
    DEFAULTS.lua                Immutable defaults
    init.lua                    Merge + access to active config, adapter/binary metadata
  core/
    init.lua / setup.lua         nvim-dap presence check, capability detection, state init
    state.lua                   Minimal session state
    capabilities.lua            Soft-dependency detection (dap-view, dapui, virtual-text)
  languages/                     One module per language: dap.adapters.* setup() +
                                 dap.configurations.* load(), kept together since the
                                 two are always in lockstep (assembly, c, go,
                                 javascript, lua, python, rust, zig)
  adapters/init.lua              Orchestrates adapter registration via registry.register()
  configurations/init.lua        Orchestrates configuration loading from languages/*
  ui/                           signs, highlights, panel UI provider, nvim-dap-virtual-text
    provider.lua                Resolves + dispatches to the active panel UI
    dapview.lua                 nvim-dap-view wiring (default)
    dapui.lua                   nvim-dap-ui wiring (opt-in)
  bindings/                     Every user-facing trigger — registration only
    init.lua                    orchestrates usercmds/keymaps/which_key/autocmds
    usercmds/init.lua            registers all :Dap* user commands
    keymaps/init.lua             default keymaps under the configurable prefix
    which_key/init.lua           optional which-key group label
    autocmds/init.lua            DAP UI cursorline toggle
  utils/                        notify, executable/Mason path + auto-install, path
                                 helpers, validation
```

lib.nvim provides notify, `cross` (platform detection, Mason `.cmd` fallback
on Windows), and `normalize` (Windows-safe path normalization).

## Security notes

No command is ever shell-interpolated: adapter definitions and `vim.system`
calls (e.g. `languages/zig.lua`'s `zig build` step) pass argv as a table, and
`utils/validation.lua`'s process picker (`ps -eo pid,comm`) is a fixed
string, not built from user input. Paths and breakpoint conditions typed via
`:Dap conditional-breakpoint`/`log-point` or the `program()` prompts are
user-supplied by design — this is a local debugger config layer, not a
network-facing surface — and are normalized (`utils/paths.lua`) rather than
executed. `.gitattributes` pins line endings to LF so `stylua`/`luacheck`
(see CI) behave the same on every contributor's checkout regardless of their
local `core.autocrlf`.
