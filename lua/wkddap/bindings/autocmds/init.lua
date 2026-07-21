---@module 'dap.bindings.autocmds'
---@brief Cursorline toggle while the nvim-dap-ui window is open.
---@description
--- Only nvim-dap-ui emits the `DapUIWindowOpen`/`DapUIWindowClose` User events,
--- so these autocmds are inert when the default nvim-dap-view provider is active.

local autocmd = require("lib.nvim.autocmd")

local M = {}

---@param opts Dap.AutocmdOptions
function M.setup(opts)
  if not opts.enable then
    return
  end

  -- Created directly via nvim_create_augroup(..., { clear = true }) rather
  -- than lib.nvim.autocmd.group(): that helper caches groups by name and
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
