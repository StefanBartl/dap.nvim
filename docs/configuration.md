# Configuration

Full defaults:

```lua
require("dap").setup({
  languages = {},  -- empty = all available

  ui = {
    enable = true,             -- wire a panel UI at all
    provider = "dap-view",     -- "dap-view" | "dap-ui" | "auto" | "none"
    -- dap_view = {},          -- optional, passed to dap-view's setup()
    -- dap_ui = {},            -- optional, passed to dapui's setup()
    virtual_text = true,  -- nvim-dap-virtual-text
    signs = true,          -- gutter signs
    highlights = true,     -- default highlight groups
  },

  keymaps = {
    enable = true,
    prefix = "<leader>d",
  },

  which_key = {
    enable = true,   -- group label for the keymaps prefix
  },

  autocmds = {
    enable = true,   -- cursorline toggle while DAP UI is open
  },

  -- Custom adapter overrides, keyed by language (merged by each adapter module)
  adapters = {},

  -- Custom launch configurations, keyed by language (appended to defaults)
  configurations = {
    go = {
      { type = "go", name = "Debug Package", request = "launch", program = "${fileDirname}" },
    },
  },

  auto_install = false,           -- reserved: Mason auto-install
  log_level = vim.log.levels.WARN,
})
```

Every key is independently overridable — set only what you want to change.
