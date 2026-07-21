---@module 'dap.config.DEFAULTS'
---@brief Immutable default configuration for dap.nvim.
---@description
--- Single source of truth. `config/init.lua` deep-merges user options over a copy
--- of this table; it is never mutated at runtime.

---@type Dap.Config
local DEFAULTS = {
  -- Languages to enable. Empty = all available (lua, javascript, typescript,
  -- c, cpp, go, python, rust, zig, assembly).
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

  -- Auto-install missing adapter binaries via mason.nvim.
  auto_install = false,

  log_level = vim.log.levels.WARN,
}

return DEFAULTS
