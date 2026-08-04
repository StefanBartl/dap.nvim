---@module 'wkddap.ui.highlights'
--- Applies the default DAP highlight groups.

local config = require("wkddap.config")

local M = {}

--- Apply `config.highlights` via `nvim_set_hl`.
---@return nil
function M.setup()
  for name, hl in pairs(config.highlights) do
    vim.api.nvim_set_hl(0, name, hl)
  end
end

return M
