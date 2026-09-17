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
  -c "lua require('plenary.busted').run('TESTS/wkddap/registry_spec.lua')"
```

Or a subdirectory:

```bash
PLENARY_PATH=... LIB_NVIM_PATH=... \
nvim --headless --noplugin -u TESTS/minimal_init.lua \
  -c "PlenaryBustedDirectory TESTS/wkddap/languages { minimal_init = 'TESTS/minimal_init.lua' }"
```

**Not `PlenaryBustedFile`**, even though it looks like the obvious counterpart
to `PlenaryBustedDirectory`. It spawns a child Neovim to run the file — like
the directory command does — but it takes no options, so it has no
`minimal_init` to pass on. The child therefore starts *without* `-u` and loads
your full personal config instead of `TESTS/minimal_init.lua`: `PLENARY_PATH`
and `LIB_NVIM_PATH` are never prepended, and the spec runs against whatever
your plugin manager happens to have installed, in an editor with all your
plugins and autocmds loaded. The `-u TESTS/minimal_init.lua` on the outer
command only configures the parent, which does nothing but spawn.

Nothing in this suite depends on that difference today — all 30 spec files
pass either way. It is still the wrong command to reach for: the failure mode
is a spec going red locally and green in CI (or the reverse) with nothing
wrong with the spec, and nothing in the output points at the environment as
the cause. The sibling sandbox.nvim suite had exactly that happen to a
timing-sensitive spec. Both forms above run against the environment CI uses.

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

## Coverage

Covered: `languages/*` (all 11 per-language modules, via two generic specs
instead of 11 near-duplicate ones — see below), `core/*`, `config/init.lua`,
`configurations/init.lua`, `registry.lua`, `adapters/init.lua`,
`integrations/menu.lua`, `bindings/*` (usercmds, keymaps, autocmds,
orchestration), `utils/*`, `ui/*` (signs, highlights, virtual_text, provider,
dapui, dapview, and the `ui/init.lua` orchestrator — all pure wiring/gating
logic exercised with a stubbed `dap-view`/`dapui`/`dap`, not a live debug
session), the top-level `init.lua` (`wkddap.setup()`, including a real,
unmocked end-to-end smoke test), and `health.lua` (smoke test only).

`languages/*`: the 11 per-language modules (`assembly`, `bash`, `browser`,
`c`, `csharp`, `go`, `javascript`, `lua`, `python`, `rust`, `zig`) share one
structural contract — `setup()`/`load()`, gated on `dap` and (mostly) on
`wkddap.config.get_adapter_path()`, `load()` filling `dap.configurations[key]`
with `{ type, name, request }`-shaped entries. `languages/contract_spec.lua`
and `languages/adapter_setup_spec.lua` assert that contract generically
across all 11 via a table-driven spec, with per-language spot checks only
where a module deviates from the shared shape (`assembly` never gates on an
adapter binary; `lua` gates on the `osv` plugin instead of a binary path).
`languages/program_prompt_spec.lua` (pre-existing) separately covers the
async `program()` prompts some of them share.

Skipped:
- `@types/init.lua` — `---@meta` type annotations, no runtime code.
- `plugin/dap.lua` — a single early-return guard, no branches worth a spec.
