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

Nothing in this suite depends on that difference today — all 31 spec files
pass either way. It is still the wrong command to reach for: the failure mode
is a spec going red locally and green in CI (or the reverse) with nothing
wrong with the spec, and nothing in the output points at the environment as
the cause. The sibling sandbox.nvim suite had exactly that happen to a
timing-sensitive spec. Both forms above run against the environment CI uses.

Round 3 re-audit (2026-09-18): every `lua/wkddap/*` file and the 11-language
table-driven contract still matched (no new language/adapter module since the
original pass). Closed four real gaps the static-reference sweep below found
untested despite passing specs elsewhere in the same modules:
- `utils/notify.lua` had no spec of its own at all (only `utils/executable.lua`,
  the other thin lib.nvim wrapper, was pinned) — new `utils/notify_spec.lua`
  pins the `[dap.nvim]` prefix passed to `lib.nvim.notify.create()` and that
  `info`/`warn`/`error` forward to the created notifier.
- `registry.lua`'s `enabled_languages()`/`registered_languages()` were only
  ever exercised transitively (via `health.check()`, always with nothing
  registered) — `registry_spec.lua` now asserts both directly, including the
  case where a language's requested name and its alias-resolved adapter name
  differ (`registered_languages()` tracks the former, `enabled_languages()`
  the latter).
- `wkddap.enabled_languages()` (the top-level delegate) had the same gap as
  its sibling `available_languages()`, which already had a test —
  `init_spec.lua` now covers both.
- `languages/lua.lua`'s `M.launch_server()` — documented in
  `docs/FEATURES/LANGUAGES.md` as the entry point a user calls from the
  Neovim instance being attached to — had zero coverage; nothing in this repo
  calls it, so unlike `setup()`/`load()` it is never exercised transitively
  through `wkddap.setup()`. Added to `languages/adapter_setup_spec.lua`
  (osv missing/present, explicit port, default port).

Method: for every file under `lua/wkddap`, diffed its `function M.<name>`
exports against every `.<name>(` occurrence anywhere under `TESTS/`, then
manually checked each hit for whether it was truly untested or only reached
transitively (most were the latter — e.g. `core/capabilities.lua`'s `detect()`
runs inside `core/setup_spec.lua`'s real `wkddap.core.setup()` calls without
being named directly). Also specifically checked for the bug families found
elsewhere in this campaign: Windows path/drive-letter splitting (none —
`utils/paths.lua` delegates to `lib.nvim.normalize`; the few raw `"/"`
concatenations in `languages/{javascript,browser,rust}.lua` build paths handed
to `node`/LLDB, which both accept forward slashes on Windows), unguarded
filesystem calls (the only one, `languages/rust.lua`'s `io.open()`, is already
guarded with `if file then`), caches that memoize a failure (`config.lua`'s
`get_adapter_path()` uses `lib.nvim.cross.executable`'s memoized `path()`, but
only the *hit* is cached — a miss falls through to the deliberately
un-memoized `mason_path()` on every call, since Mason installs mid-session),
health.lua calling into a missing dependency inside its own "missing" branch
(none — every `check_require`/`pcall(require, ...)` in `health.lua` only
reports, never calls further into the probed module), and an autocmd teardown
handler wiping the buffer it's called for, or a second `setup()` stacking
duplicate autocmds (`bindings/autocmds/init.lua` is the only augroup in this
repo, and it already creates it directly via `nvim_create_augroup(...,
{ clear = true })` specifically to avoid the latter — see the comment there;
no `BufWipeout`/`BufDelete` autocmd exists anywhere in this repo).

No new bugs found; nothing pinned.

One thing looked at and deliberately left alone: `wkddap.available_languages()`
and `.enabled_languages()` both `pcall(require, "wkddap.registry")` and fall
back to `{}` if that fails. That fallback branch is untested — forcing it
would mean injecting a broken `wkddap.registry` via `package.preload` to make
one of this plugin's own sibling modules fail to load, a scenario that would
just as likely break every other spec file's `require` calls first. Treated
as defensive-but-unreachable, same category as the `@types`/single-guard
files below, rather than a gap worth a contrived test.

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
