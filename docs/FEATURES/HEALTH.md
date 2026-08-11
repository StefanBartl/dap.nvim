# Health

## `:checkhealth wkddap`

A single health check covering the whole plugin: Neovim version, nvim-dap
presence, `lib.nvim` module availability, the configured vs. actually-active
panel UI provider (flagging a fallback), nvim-dap-virtual-text and
which-key presence, per-language adapter availability (resolved through the
same alias table used at registration), enabled languages, registry stats
(`available`/`registered`/`enabled` counts), any `registry.validate()`
errors for already-enabled languages, and a pre-flight check for the `:Dap`
command's `lib.nvim.usercmd.composer` route table.

- **Module:** `lua/wkddap/health.lua` (`M.check`)
- **Usercmds:** `:checkhealth wkddap`
