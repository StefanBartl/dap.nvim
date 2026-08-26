---@module 'wkddap.bindings'
--- Orchestrates dap.nvim's bindings: usercmds, keymaps, which-key, autocmds.

local notify = require("lib.nvim.notify").create("[dap.nvim.bindings]")

local M = {}

---Wire up every binding for the resolved config.
---@param cfg Dap.Config
---@return nil
function M.setup(cfg)
  require("wkddap.bindings.usercmds").setup()

  if cfg.keymaps.enable then
    -- keymaps.setup() requires("dap") eagerly (to bind functions directly);
    -- pcall so a missing nvim-dap degrades gracefully instead of aborting
    -- the rest of setup() (which-key/autocmds still get wired).
    -- The which-key group label is one field in the keymap spec now, so the
    -- toggle is handed over rather than acted on here.
    local ok, err =
      pcall(require("wkddap.bindings.keymaps").setup, cfg.keymaps, cfg.which_key.enable)
    if not ok then
      notify.warn("Skipped keymaps: " .. tostring(err))
    end
  end

  require("wkddap.bindings.autocmds").setup(cfg.autocmds)
end

return M
