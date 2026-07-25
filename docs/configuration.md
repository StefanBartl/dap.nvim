# Configuration

Full defaults:

```lua
require("wkddap").setup({
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

  -- Custom launch configurations, keyed by language (appended to defaults
  -- unless the list also has `replace = true`, which replaces instead)
  configurations = {
    go = {
      { type = "go", name = "Debug Package", request = "launch", program = "${fileDirname}" },
    },
    python = {
      replace = true, -- discard the built-in python configurations entirely
      { type = "python", name = "Custom", request = "launch", program = "${file}" },
    },
  },

  auto_install = false,  -- install missing required adapters via `:MasonInstall`
                          -- (mason.nvim must be installed separately)
  log_level = vim.log.levels.WARN,
})
```

Every key is independently overridable — set only what you want to change.
