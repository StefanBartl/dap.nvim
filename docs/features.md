# Features

| Language | Adapter | Notes |
|---|---|---|
| Lua | OSV (`one-small-step-for-vimkind`) | Neovim-native, attach-only |
| JavaScript/TypeScript | `js-debug-adapter` | Node.js; via Mason |
| C/C++ | CodeLLDB (also registers plain `lldb`) | Via Mason |
| Go | Delve (`dlv`) | Go 1.16+ |
| Python | `debugpy` | Python 3.7+ |
| Rust | CodeLLDB, with `rustc`-provided pretty printers | Cargo-friendly launch config |
| Zig | CodeLLDB/`lldb` | Includes a "build first" launch config |
| Assembly | GDB | NASM/GAS/AT&T filetypes |

Aliases: `typescript`/`javascriptreact`/`typescriptreact` → `javascript`,
`cpp`/`c++` → `c`, `asm`/`nasm`/`gas` → `assembly`.

Beyond adapters: a **memory view** (`:Dap memory`, `<leader>dm`) shows and
edits an address range of the running debuggee as hex or bits, over DAP
`readMemory`/`writeMemory` of the active session — see
[FEATURES/MEMORY.md](FEATURES/MEMORY.md). Works with any adapter that
advertises those capabilities (checked with GDB 16.3's `gdb -i dap`). The
same view opens read-only in a **companion window** (`:Dap memory-window`,
`<leader>dM`): a second Neovim in its own terminal, say on a second monitor,
navigated from there while the requests stay in this instance.

Every adapter/configuration module is isolated and only registered if its
binary (or Neovim plugin, for Lua) is actually available — see
[Health Check](health.md).
