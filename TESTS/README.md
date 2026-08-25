# dap.nvim tests

A [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) busted-style
suite. Specs stick to code paths that don't require a real debug adapter
binary (codelldb, delve, debugpy, gdb, ...) or `nvim-dap`/`nvim-dap-ui`
themselves to be installed — registry/usercmd logic only.

## Running locally

Point `PLENARY_PATH` and `LIB_NVIM_PATH` at wherever those two plugins live
in your own setup (e.g. your plugin manager's install dir), then:

```bash
PLENARY_PATH=/path/to/plenary.nvim \
LIB_NVIM_PATH=/path/to/lib.nvim \
nvim --headless --noplugin -u TESTS/minimal_init.lua \
  -c "PlenaryBustedDirectory TESTS/wkddap { minimal_init = 'TESTS/minimal_init.lua' }"
```

A single file:

```bash
PLENARY_PATH=... LIB_NVIM_PATH=... \
nvim --headless --noplugin -u TESTS/minimal_init.lua \
  -c "PlenaryBustedFile TESTS/wkddap/registry_spec.lua"
```

## Writing a new spec

- One spec file per module, mirroring `lua/wkddap/...`'s path under
  `TESTS/wkddap/...`.
- Prefer asserting on failure/validation paths that don't need a real
  adapter binary on `$PATH` (e.g. `registry.register("nonexistent")`)
  over paths that only succeed when codelldb/gdb/etc. are installed.
- Each spec file runs in its own `nvim --headless` subprocess (plenary
  spawns one per file), so `package.loaded` never leaks between files —
  only between `it()` blocks *within* the same file, which matters for
  specs that reload a module to reset its internal state.
