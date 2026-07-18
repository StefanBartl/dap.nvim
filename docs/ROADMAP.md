# dap.nvim — Roadmap

## Implemented (v0.1)

- Adapter + launch-configuration registration for 9 languages: Lua,
  JavaScript/TypeScript, C/C++, Go, Python, Rust, Zig, Assembly
- Language alias resolution (`typescript` → `javascript`, `cpp` → `c`, ...)
- Adapter validation with Mason-path fallback (`config.validate_adapter`)
- `registry.lua` lifecycle: register/unregister/enabled/available/stats
- nvim-dap-virtual-text wiring, default signs/highlights
- `config/DEFAULTS.lua` + `config/init.lua` merge system
- User-configurable keymaps (single prefix), which-key group label, and a
  full `:Dap*` user-command set independent of keymaps
- Pluggable panel UI (`ui.provider`): nvim-dap-view by default, nvim-dap-ui
  opt-in, with fallback when the preferred one is missing — exactly one is
  wired, and keymaps/commands dispatch through `ui/provider.lua`
- `:checkhealth dap_nvim` covering nvim-dap/lib.nvim/UI companions/adapters
- `docs/BINDINGS.md` cheatsheet (keymaps, commands, autocmds)
- Built on lib.nvim as a deliberate shared dependency (notify, cross-platform
  Mason path resolution, path normalization)

## Planned

- [ ] `auto_install`: actually drive `MasonInstall` for missing required
  adapters instead of only warning in `:checkhealth`
- [ ] Per-language `configurations` override should support full *replace*
  as well as the current *append* semantics
- [ ] REPL/console keymap parity check against upstream nvim-dap defaults
  as new DAP features land
- [ ] Consider exposing `registry.stats()` / `validate()` through
  `:checkhealth` output directly instead of only via Lua API
- [ ] Evaluate splitting `adapters/*` + `configurations/*` pairs into a
  single `languages/<lang>.lua` module per language if the two stay in
  lockstep long-term (currently kept parallel to match the original
  `wkddap` prototype's structure)
