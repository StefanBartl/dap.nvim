# Languages

Every language lives in its own `lua/wkddap/languages/<lang>.lua` module with
a `setup()` (registers `dap.adapters.*`) and a `load()` (registers
`dap.configurations.*`). Both are only called for languages that are
requested (`opts.languages`, empty = all) *and* whose adapter is actually
resolvable — an unavailable binary means that language is silently skipped,
not a hard error (see [HEALTH.md](HEALTH.md) for how to see why).

## Multi-language debug adapters & launch configs

Registers nvim-dap adapters and ready-to-use launch configurations for eleven
targets, each isolated in its own module and only wired when its binary/plugin
is actually available.

- **Module:** `lua/wkddap/languages/*.lua` (`setup`, `load`)
- **Config:** `opts.languages` (default: empty, meaning all)

| Language | Adapter | Notes |
|---|---|---|
| Lua | OSV (`one-small-step-for-vimkind`) | Neovim-native, attach-only; `M.launch_server(port)` starts the in-process debug server (default port 8086) |
| JavaScript/TypeScript | `js-debug-adapter` (`pwa-node`) | Launch + Attach (with a process picker) configs |
| C/C++ | CodeLLDB (also registers plain `lldb`) | Prompts for the executable path |
| Go | Delve (`dlv`) | Debug / Debug Package / Debug Test configs |
| Python | `debugpy` | `pythonPath` resolves `$VIRTUAL_ENV` first, falls back to `python3` |
| Rust | CodeLLDB | Cargo-friendly; bootstraps `rustc`'s own LLDB pretty-printers via `initCommands` |
| Zig | CodeLLDB/`lldb` | Two configs: plain launch, and "build first" which runs `zig build` before launching |
| Assembly | GDB | NASM/GAS/AT&T filetypes, `stopAtBeginningOfMainSubprogram = false` |
| Bash | `bash-debug-adapter` | One config shared by `sh`/`bash`/`zsh`/`ksh`; `pathBashdb*` left empty so the adapter's bundled bashdb is used |
| C#/.NET | `netcoredbg` | Prompts for the DLL path, defaulting into `bin/Debug/`; forces `noshellslash` on Windows when the adapter is registered |
| Browser | `js-debug-adapter` (`pwa-chrome`) | Attach (port 9222) + Launch configs, appended to JS/TS/JSX/TSX/Astro so the node configs are not replaced |

The last three were carried over from the nvim config's `lsp/debug_adapters/`,
which registered them at module load and was never required by anything. Its
`go` and `node` modules were dropped rather than ported: the `go` and
`javascript` modules here already cover them, with more configurations.

Several launch configs prompt interactively for a value (executable path,
host/port, breakpoint condition) via `lib.nvim.ui.kit`, using nvim-dap's own
`coroutine.wrap()`-based config resolution: the config function suspends with
`coroutine.yield()` and the prompt's `on_submit`/`on_cancel` resumes it.

## Language adapter registry

Tracks which languages are registered vs. enabled, resolves aliases before
validating, and is the single gate `setup()` calls through — a language that
fails validation is skipped with a warning instead of aborting the rest of
setup.

- **Module:** `lua/wkddap/registry.lua` (`register`, `register_all`,
  `is_enabled`, `validate`, `stats`)

## Adapter auto-detection with Mason fallback

- **Tab:** true
- **Module:** `lua/wkddap/config/init.lua` (`get_adapter_path`,
  `validate_adapter`)

Before any adapter or launch config is registered, dap.nvim resolves the
underlying binary and validates it is actually present.

### Resolution order

1. **`vim.fn.exepath(binary)`** — anything already on `$PATH` wins first.
2. **Mason's bin directory** — `stdpath("data")/mason/bin/<binary>`, with a
   `.cmd` suffix appended on Windows (`lib.nvim.cross.is_windows()`). Checked
   with `vim.uv.fs_stat`, not `exepath`, since Mason shims aren't always on
   `$PATH`.
3. **Plugin-type adapters** (currently only Lua/OSV) skip binary resolution
   entirely and are validated with `pcall(require, "osv")` instead.

### Required vs. optional

Each entry in `config.adapter_binaries` carries a `required` flag. A missing
*required* adapter (JS, Go, Python, C, Rust, Zig, Assembly) produces a
specific error — naming the Mason package to install, or saying to install it
manually when there is no Mason package (GDB). A missing *optional* one
(currently only Lua/OSV) is reported but does not block setup.

## `auto_install`: install missing adapters via Mason

Scans the requested languages for required, Mason-backed adapters that
`get_adapter_path` cannot currently resolve, and runs a single `:MasonInstall`
for all of them.

- **Module:** `lua/wkddap/utils/mason.lua` (`ensure_installed`)
- **Config:** `opts.auto_install` (default `false`)

`mason.nvim` must be installed separately — if it isn't, this warns and does
nothing (it does not install Mason itself).

## Custom adapter/configuration overrides

Per-language launch configurations can be extended or replaced entirely
without touching a language module.

- **Module:** `lua/wkddap/configurations/init.lua` (`load_all`)
- **Config:** `opts.configurations` (keyed by language; append by default,
  or set `replace = true` alongside the entries to discard the built-ins)
- **Config:** `opts.adapters` (reserved — accepted by `setup()` and passed
  through to `adapters.register_all`, currently not consumed further)

## Language aliases

Filetype/language spellings are folded onto one canonical adapter module so
`typescript`, `cpp`, and `nasm` don't need their own language files.

- **Module:** `lua/wkddap/config/init.lua` (`language_aliases`)

| Alias | Canonical |
|---|---|
| `typescript`, `typescriptreact`, `javascriptreact` | `javascript` |
| `cpp`, `c++` | `c` |
| `asm`, `nasm`, `gas` | `assembly` |
| `sh`, `zsh`, `ksh` | `bash` |
| `cs`, `fsharp`, `dotnet` | `csharp` |

`browser` has no alias on purpose. It is not a filetype but an independently
selectable adapter: someone debugging a Node service does not necessarily want
Chrome attach configurations in the same list, so it has to be asked for by
name.
