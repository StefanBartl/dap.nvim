---@module 'dap_nvim.ui'
---@brief Wires signs, highlights, the panel UI provider, and nvim-dap-virtual-text.
---@description
--- The panel UI is provided by exactly one of nvim-dap-view (default) or
--- nvim-dap-ui (opt-in), selected via `ui.provider`; see ui/provider.lua.

local M = {}

---@param opts Dap.UiOptions
function M.setup(opts)
  local ok_signs, signs = pcall(require, "dap_nvim.ui.signs")
  if ok_signs and opts.signs then
    pcall(signs.setup)
  end

  local ok_hl, highlights = pcall(require, "dap_nvim.ui.highlights")
  if ok_hl and opts.highlights then
    pcall(highlights.setup)
  end

  if opts.enable then
    local ok_provider, provider = pcall(require, "dap_nvim.ui.provider")
    if ok_provider then
      pcall(provider.setup, opts)
    end
  end

  if opts.virtual_text then
    local ok_vt, virtual_text = pcall(require, "dap_nvim.ui.virtual_text")
    if ok_vt then
      pcall(virtual_text.setup)
    end
  end
end

return M
