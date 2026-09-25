---@meta
---@module 'wkddap.@types'
--- Type declarations for dap.nvim's configuration options.

---@class Dap.Config
---@field languages? string[] Languages to enable (empty = all available)
---@field ui? Dap.UiOptions UI integration options
---@field keymaps? Dap.KeymapOptions Keymap configuration
---@field which_key? Dap.WhichKeyOptions which-key integration
---@field autocmds? Dap.AutocmdOptions Autocommand configuration
---@field menu? Dap.MenuOptions nvzone/menu context-menu contribution
---@field integrations? Dap.IntegrationsOptions Which hosts may drive this plugin (`ui_menu`)
---@field adapters? table<string, table|function> Adapter overrides keyed by nvim-dap
---  adapter name (`codelldb`, `pwa-node`, ...): a table is deep-merged over the
---  built-in definition, a function replaces it
---@field configurations? table<string, table[]> Custom launch configurations, keyed
---  by language (appended by default; set `replace = true` on the list to
---  replace the language's configurations instead)
---@field auto_install? boolean Auto-install missing adapters via Mason
---@field log_level? integer|string nvim-dap log file level: a vim.log.levels value or a name ("trace" .. "error")

---@class Dap.UiOptions
---@field enable boolean Enable the panel UI integration
---@field provider Dap.UiProvider Panel UI to wire: 'dap-view' (default), 'dap-ui', 'auto' or 'none'
---@field dap_view? table Options passed to `require("dap-view").setup()`
---@field dap_ui? table Options passed to `require("dapui").setup()`
---@field virtual_text boolean|table nvim-dap-virtual-text: `true` wires it with dap.nvim's
---  defaults, a table is passed to its `setup()` as given, `false` leaves it to
---  your own plugin spec
---@field signs boolean Configure gutter signs
---@field highlights boolean Configure default highlight groups

---@class Dap.KeymapOptions
---@field enable boolean Enable default keymaps
---@field prefix string Leader prefix for DAP keymaps (default "<leader>d")

---@class Dap.WhichKeyOptions
---@field enable boolean Register a which-key group label for the keymap prefix

---@class Dap.AutocmdOptions
---@field enable boolean Enable default autocommands (DAP UI cursorline toggle)

---@class Dap.MenuOptions
---@field enable boolean Provide nvzone/menu entries via integrations/menu.lua. Default true.

---@class Dap.IntegrationsOptions
---@field ui_menu boolean Let ui.nvim's right-click menu (`ui.menu`) compose the DAP fly-out. Default true.

return {}
