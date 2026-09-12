# Installation

See [requirements.md](requirements.md) for the full required/optional list —
panel UI choice is covered separately in [panel-ui.md](panel-ui.md).

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
