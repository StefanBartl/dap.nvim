---@module 'wkddap.bindings.autocmds'
--- Cursorline toggle while the nvim-dap-ui window is open.
---
--- Only nvim-dap-ui emits the `DapUIWindowOpen`/`DapUIWindowClose` User events,
--- so these autocmds are inert when the default nvim-dap-view provider is active.

local autocmd = require("lib.nvim.bindings.autocmd")

local M = {}

--- Register the cursorline-toggle autocmds, if enabled.
---@param opts Dap.AutocmdOptions
---@return nil
function M.setup(opts)
  if not opts.enable then
    return
  end

  -- Created directly via nvim_create_augroup(..., { clear = true }) rather
  -- than lib.nvim.bindings.autocmd.group(): that helper caches groups by name and
  -- skips the clear on subsequent calls, which would stack duplicate
  -- autocmds if setup() ever re-runs.
  local group = vim.api.nvim_create_augroup("DapNvimAuto", { clear = true })

  autocmd.create("User", function()
    vim.wo.cursorline = true
  end, {
    group = group,
    pattern = "DapUIWindowOpen",
    desc = "Enable cursorline while DAP UI is open",
  })

  autocmd.create("User", function()
    vim.wo.cursorline = false
  end, {
    group = group,
    pattern = "DapUIWindowClose",
    desc = "Disable cursorline when DAP UI closes",
  })
end

return M
