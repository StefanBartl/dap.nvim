# Health Check

```vim
:checkhealth wkddap
```

Verifies Neovim version, nvim-dap presence, lib.nvim modules, optional UI
companions (the configured and active panel UI, nvim-dap-virtual-text,
which-key), per-language adapter availability (binary on `$PATH` or via
Mason), and registry state (`registry.stats()` counts plus any
`registry.validate()` errors for already-enabled languages).
