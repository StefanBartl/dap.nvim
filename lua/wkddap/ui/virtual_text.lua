---@module 'wkddap.ui.virtual_text'
--- nvim-dap-virtual-text setup (soft dependency).
---
--- nvim-dap-virtual-text has one global `setup()`, and whoever calls it last
--- owns its configuration. `ui.virtual_text` decides who that is: `true`
--- applies dap.nvim's defaults (`config.virtual_text`), a table is handed to
--- the plugin's `setup()` as given (mirroring `ui.dap_view` / `ui.dap_ui`),
--- and `false` means dap.nvim does not call it at all -- the plugin still
--- works, configured by the user's own plugin spec.

local config = require("wkddap.config")

local M = {}

--- Wire nvim-dap-virtual-text, if installed.
---@param opts? table|boolean  Options for its `setup()`; anything but a table
---  means dap.nvim's defaults (`config.virtual_text`).
---@return nil
function M.setup(opts)
  local ok, vt = pcall(require, "nvim-dap-virtual-text")
  if not ok then
    return
  end

  vt.setup(type(opts) == "table" and opts or config.virtual_text)
end

return M
