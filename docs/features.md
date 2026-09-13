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

Every adapter/configuration module is isolated and only registered if its
binary (or Neovim plugin, for Lua) is actually available — see
[Health Check](health.md).
