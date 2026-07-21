---@meta
---@module 'dap.@types'

---@class Dap.Config
---@field languages string[] Languages to enable (empty = all available)
---@field ui Dap.UiOptions UI integration options
---@field keymaps Dap.KeymapOptions Keymap configuration
---@field which_key Dap.WhichKeyOptions which-key integration
---@field autocmds Dap.AutocmdOptions Autocommand configuration
---@field adapters? table<string, table> Custom adapter overrides
---@field configurations? table<string, table[]> Custom launch configurations
---@field auto_install boolean Auto-install missing adapters via Mason
---@field log_level integer Logging level (vim.log.levels)

---@class Dap.UiOptions
---@field enable boolean Enable the panel UI integration
---@field provider Dap.UiProvider Panel UI to wire: 'dap-view' (default), 'dap-ui', 'auto' or 'none'
---@field dap_view? table Options passed to `require("dap-view").setup()`
---@field dap_ui? table Options passed to `require("dapui").setup()`
---@field virtual_text boolean Enable nvim-dap-virtual-text
---@field signs boolean Configure gutter signs
---@field highlights boolean Configure default highlight groups

---@class Dap.KeymapOptions
---@field enable boolean Enable default keymaps
---@field prefix string Leader prefix for DAP keymaps (default "<leader>d")

---@class Dap.WhichKeyOptions
---@field enable boolean Register a which-key group label for the keymap prefix

---@class Dap.AutocmdOptions
---@field enable boolean Enable default autocommands (DAP UI cursorline toggle)

return {}
