---@module 'wkddap.config.DEFAULTS'
--- Immutable default configuration for dap.nvim.
---
--- Single source of truth. `config/init.lua` deep-merges user options over a copy
--- of this table; it is never mutated at runtime.

---@type Dap.Config
local DEFAULTS = {
  -- Languages to enable. Empty = all available (lua, javascript, c, go,
  -- python, rust, zig, assembly, bash, csharp, browser; see wkddap.registry).
  -- Aliases such as typescript/cpp/nasm resolve automatically.
  languages = {},

  ui = {
    enable = true,
    -- Panel UI provider. Exactly one is wired: "dap-view" (default, modern and
    -- lighter), "dap-ui" (opt-in, richer layout), "auto" (first installed), or
    -- "none". An uninstalled preference falls back to the other provider.
    provider = "dap-view",
    -- Deliberately unset: `ui.dap_view` / `ui.dap_ui` are optional option
    -- tables passed straight to the respective plugin's setup(). Absent means
    -- "use the plugin's own defaults" (dap-view) resp. `config.dapui_layout`.
    -- nvim-dap-virtual-text: true = dap.nvim's defaults (config.virtual_text),
    -- a table = passed to its setup() as given, false = your own spec owns it.
    virtual_text = true,
    signs = true,
    highlights = true,
  },

  keymaps = {
    enable = true,
    prefix = "<leader>d",
  },

  which_key = {
    enable = true,
  },

  autocmds = {
    enable = true,
  },

  -- nvzone/menu context-menu contribution (integrations/menu.lua). dap.nvim
  -- ships no trigger code and no nvzone/menu dependency itself; this only
  -- gates whether M.items()/M.submenu() return entries for a host to compose.
  menu = {
    enable = true,
  },

  -- Per-adapter overrides (keyed by nvim-dap adapter name) resp. custom
  -- launch configurations (keyed by language). Empty = none; present here
  -- (not simply absent) so config/init.lua's generic "must be a table" guard
  -- covers them too -- otherwise a wrong-typed value (a string, say) would
  -- sail past validation and only blow up later, inside register_all()/
  -- load_all()'s `next(...)` call, as a raw Lua error instead of a clean
  -- "using the default" warning.
  adapters = {},
  configurations = {},

  -- Auto-install missing required adapter binaries via `:MasonInstall`
  -- (mason.nvim must be installed separately).
  auto_install = false,

  log_level = vim.log.levels.WARN,
}

return DEFAULTS
