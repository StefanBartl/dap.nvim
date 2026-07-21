---@module 'dap.bindings'
---@brief Orchestrates dap.nvim's bindings: usercmds, keymaps, which-key, autocmds.

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
    local ok, err = pcall(require("wkddap.bindings.keymaps").setup, cfg.keymaps)
    if not ok then
      notify.warn("Skipped keymaps: " .. tostring(err))
    end

    if cfg.which_key.enable then
      pcall(require("wkddap.bindings.which_key").setup, cfg.keymaps.prefix)
    end
  end

  require("wkddap.bindings.autocmds").setup(cfg.autocmds)
end

return M
