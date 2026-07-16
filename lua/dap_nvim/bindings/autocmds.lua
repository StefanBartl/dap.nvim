---@module 'dap_nvim.bindings.autocmds'
---@brief Cursorline toggle while the nvim-dap-ui window is open.

local M = {}

---@param opts Dap.AutocmdOptions
function M.setup(opts)
  if not opts.enable then
    return
  end

  local group = vim.api.nvim_create_augroup("DapNvimAuto", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "DapUIWindowOpen",
    desc = "Enable cursorline while DAP UI is open",
    callback = function()
      vim.wo.cursorline = true
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "DapUIWindowClose",
    desc = "Disable cursorline when DAP UI closes",
    callback = function()
      vim.wo.cursorline = false
    end,
  })
end

return M
