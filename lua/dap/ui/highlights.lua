---@module 'dap.ui.highlights'
---@brief Applies the default DAP highlight groups.

local config = require("dap.config")

local M = {}

function M.setup()
  for name, hl in pairs(config.highlights) do
    vim.api.nvim_set_hl(0, name, hl)
  end
end

return M
