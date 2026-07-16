---@module 'dap_nvim.ui.signs'
---@brief Defines the default DAP gutter signs.

local config = require("dap_nvim.config")

local M = {}

function M.setup()
  for name, sign in pairs(config.signs) do
    vim.fn.sign_define(name, sign)
  end
end

return M
