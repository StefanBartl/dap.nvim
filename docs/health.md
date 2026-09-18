# Health Check

```vim
:checkhealth wkddap
```

Worth running before the first session, not after: a missing adapter
otherwise only shows up as a session that never starts.

Verifies Neovim version, nvim-dap presence, lib.nvim and ui.nvim modules, optional UI
companions (the configured and active panel UI, nvim-dap-virtual-text,
which-key), per-language adapter availability (binary on `$PATH` or via
Mason), the `setup()` options themselves (unknown or mistyped keys the merge
had to ignore), and registry state (`registry.stats()` counts plus any
`registry.validate()` errors for already-enabled languages).
