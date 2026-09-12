# Requirements

## Required

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | the `:Dap` command tree and the shared UI kit |
| [nvim-dap](https://github.com/mfussenegger/nvim-dap) | this plugin configures it, it does not replace it |
| A debug adapter per language | required for that language only; see [installation.md](installation.md) for where each comes from |

## Optional

Each detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view) | The default panel UI |
| [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) | The alternative panel UI, selected with `ui.provider` |
| [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text) | Inline variable values next to the code |
| [one-small-step-for-vimkind](https://github.com/jbyuki/one-small-step-for-vimkind) | Lua debugging — required for that target specifically |
| [mason.nvim](https://github.com/williamboman/mason.nvim) | Fallback location for adapter binaries |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | The `<leader>d` group label |
| [nvzone/menu](https://github.com/nvzone/menu) | A host for the context-menu entries — see [integrations.md](integrations.md) |
