# Installation

## Requirements

- Neovim 0.9+
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) (required — dap.nvim
  configures it, it does not replace it)
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)
- Panel UI (optional, pick one): [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view)
  (default) **or** [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) (opt-in
  via `ui.provider`) — see [Panel UI](panel-ui.md)
- Optional: [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text),
  [which-key.nvim](https://github.com/folke/which-key.nvim), and
  [mason.nvim](https://github.com/williamboman/mason.nvim) for adapter binaries

## lazy.nvim

```lua
{
  "StefanBartl/dap.nvim",
  dependencies = {
    "StefanBartl/lib.nvim",
    "mfussenegger/nvim-dap",
    "igorlfs/nvim-dap-view",      -- default panel UI
    -- "rcarriga/nvim-dap-ui",    -- opt-in alternative (ui.provider = "dap-ui")
    -- "nvim-neotest/nvim-nio",   -- required by nvim-dap-ui
    "theHamsta/nvim-dap-virtual-text", -- optional
    "jbyuki/one-small-step-for-vimkind", -- optional, Lua debugging
  },
  event = "VeryLazy",
  opts = {},
}
```

## packer.nvim

```lua
use({
  "StefanBartl/dap.nvim",
  requires = {
    "StefanBartl/lib.nvim",
    "mfussenegger/nvim-dap",
    "igorlfs/nvim-dap-view",
    "theHamsta/nvim-dap-virtual-text",
    "jbyuki/one-small-step-for-vimkind",
  },
  config = function()
    require("wkddap").setup({})
  end,
})
```

## Adapter Installation

Via Mason:

```vim
:MasonInstall js-debug-adapter codelldb delve debugpy
```

Manual:
- **Delve (Go):** `go install github.com/go-delve/delve/cmd/dlv@latest`
- **debugpy (Python):** `pip install debugpy`
- **CodeLLDB:** download from [GitHub Releases](https://github.com/vadimcn/codelldb/releases)
