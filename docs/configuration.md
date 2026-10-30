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
    virtual_text = true,  -- nvim-dap-virtual-text: true (dap.nvim's defaults),
                          -- an options table (passed to its setup() as given),
                          -- or false (your own plugin spec owns its setup())
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

  -- nvzone/menu context-menu contribution (integrations/menu.lua). dap.nvim
  -- ships no trigger code and no nvzone/menu dependency itself; this only
  -- gates whether items()/submenu() return entries for a host to compose.
  menu = {
    enable = true,
  },

  -- Which hosts may drive this plugin. `ui_menu = false` keeps ui.nvim's
  -- right-click menu from composing the DAP fly-out.
  integrations = {
    ui_menu = true,
  },

  -- Start the debuggee in a terminal.nvim terminal named `dap:<configuration name>` (it shows up in
  -- `:Terminal list`, can be hidden and toggled back) instead of nvim-dap's own buffer. Needs
  -- terminal.nvim. Applies to the adapters registered by setup() and their overrides.
  terminal = { enable = false, layout = "split", name = "dap" },

  -- Memory view (`:Dap memory`, docs/FEATURES/MEMORY.md). Like Visual Studio's
  -- memory window, opening it (or jumping with `a`) shows `context_rows`
  -- rows of 16 bytes above the target, the cursor on the target byte.
  -- A whole number 0..15; 0 = the target is the first row.
  memory = { context_rows = 4 },

  -- Adapter overrides, keyed by nvim-dap adapter name (`codelldb`,
  -- `pwa-node`, `coreclr`, ...), applied after the language modules
  -- registered theirs. A table is deep-merged over the built-in definition;
  -- a function replaces it. A name nothing registered adds a new adapter.
  adapters = {
    codelldb = { executable = { command = "/usr/local/bin/codelldb" } },
  },

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
  -- Level of nvim-dap's own log file (handed to `dap.set_log_level()`):
  -- a vim.log.levels value or a name such as "debug".
  log_level = vim.log.levels.WARN,
})
```

Every key is independently overridable — set only what you want to change.

Options are checked before they are merged. An unknown key — at the top level
or inside `ui`, `which_key`, `autocmds`, `menu`, `memory` — is ignored with a warning
that names the nearest known key (`keymaps = { enabled = false }` →
"did you mean 'keymaps.enable'?"), and an option table given as something
other than a table (`keymaps = false`) falls back to that table's defaults.
Both are listed again under `:checkhealth wkddap`. `keymaps` also accepts
per-action overrides (`toggle_breakpoint = "<leader>xb"`, `eval = false`), so
its keys are not checked.

`languages` given as something other than a table (`languages = "python"`) is
the one exception to "falls back to that table's defaults": its default is
`{}`, which means "every available language" (see above), so falling back to
it would turn a typo into every adapter — and, with `auto_install = true`,
every missing Mason package — getting installed. It is dropped without
resolving to any real language instead, which registers nothing and is
reported the same way.
