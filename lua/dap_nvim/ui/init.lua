---@module 'dap_nvim.ui'
---@brief Wires signs, highlights, nvim-dap-ui, and nvim-dap-virtual-text.

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
    local ok_dapui, dapui_mod = pcall(require, "dap_nvim.ui.dapui")
    if ok_dapui then
      pcall(dapui_mod.setup)
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
