# dap.nvim — Roadmap

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
