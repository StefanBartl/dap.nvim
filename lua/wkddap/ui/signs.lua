---@module 'wkddap.ui.signs'
--- Defines the default DAP gutter signs.

local config = require("wkddap.config")

local M = {}

--- Define `config.signs` via `vim.fn.sign_define`.
---@return nil
function M.setup()
  for name, sign in pairs(config.signs) do
    vim.fn.sign_define(name, sign)
  end
end

return M
