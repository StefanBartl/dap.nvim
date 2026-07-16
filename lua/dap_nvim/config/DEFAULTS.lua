---@module 'dap_nvim.config.DEFAULTS'
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
