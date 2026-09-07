# Contributing to dap.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/dap.nvim/issues); pull requests
very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it to
the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/dap.nvim")
require("wkddap").setup({})
```

The module namespace is `wkddap`, not `dap`. `dap` belongs to
[nvim-dap](https://github.com/mfussenegger/nvim-dap), and shadowing it would
break every other plugin's `require("dap")`. Nothing in this repository may
claim that name.

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation.
- **This plugin configures nvim-dap, it does not wrap it.** Anything a user
  could reasonably want to reach through `require("dap")` stays reachable. We add
  adapters, configurations and defaults; we do not intercept the protocol.
- **A missing adapter is a health-check finding, not a runtime error.** Detection
  and validation happen up front so `:checkhealth wkddap` can say what is wrong,
  rather than the user discovering it when a session silently fails to start.
- Nothing platform-specific in a module — paths and process handling go through
  `lib.nvim`'s `cross.*` layer. The C#/.NET adapter's `noshellslash` handling on
  Windows is the documented exception, and it is scoped to that registration.
- Commands are registered through `lib.nvim.bindings.usercmd.composer`, never
  with a bare `nvim_create_user_command`.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/wkddap/adapters/` | One file per adapter: how to find its binary and how to launch it |
| `lua/wkddap/configurations/` | The launch configurations offered per filetype |
| `lua/wkddap/languages/` | The per-language wiring that ties an adapter to its configurations |
| `lua/wkddap/ui/` | Panel UI provider selection (nvim-dap-view, nvim-dap-ui) |
| `lua/wkddap/bindings/` | The `:Dap` route tree and the default keymaps |
| `lua/wkddap/config/` | Defaults and `setup()` validation |
| `lua/wkddap/integrations/` | Soft-dependency bridges (nvzone/menu) |
| `lua/wkddap/core/`, `utils/` | Adapter discovery, validation, shared helpers |
| `docs/` | Everything the README links to |
| `TESTS/` | The spec suite, mirroring `lua/wkddap/`'s paths |

## Adding a language

1. Add the adapter under `lua/wkddap/adapters/`: where its binary lives, in what
   order to look, and what a working invocation is. Include the Mason name if
   Mason ships it.
2. Add the launch configurations under `lua/wkddap/configurations/`. Prefer
   several small named configs over one config with prompts for everything.
3. Wire the two together in `lua/wkddap/languages/`, and append rather than
   replace when a filetype already has configurations — that is how the Chrome
   configs coexist with the Node ones.
4. Teach `health.lua` to report on the new adapter.
5. Add the row to [`FEATURES/LANGUAGES.md`](FEATURES/LANGUAGES.md) and the
   installation note to [`installation.md`](installation.md).
6. Add a spec under `TESTS/`.

## Tests

`TESTS/` is a [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
busted-style suite; no debug adapter has to be installed to run it.
[GitHub Actions](../.github/workflows/ci.yml) runs it on every push and PR to
`main`.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/`.
4. Open a PR with a clear description of what changed and why.
