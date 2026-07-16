---@module 'dap_nvim'
---@brief Public entry point for dap.nvim.
---@description
--- A config layer on top of mfussenegger/nvim-dap: multi-language adapters and
--- launch configurations (Lua, JS/TS, C/C++, Go, Python, Rust, Zig, Assembly),
--- automatic adapter detection/validation, nvim-dap-ui + nvim-dap-virtual-text
--- wiring, user-configurable keymaps/commands, and built-in health checks.
---
--- Depends on lib.nvim (deliberate shared dependency).
---
--- Example: >lua
---   require("dap_nvim").setup()
---   require("dap_nvim").setup({
---     languages = { "lua", "javascript", "go" },
---     keymaps = { prefix = "<leader>d" },
---   })
--- <

local M = {}

---@type Dap.Config|nil
M._config = nil

---@type boolean
M._initialized = false

--- Setup dap.nvim with the provided options.
---@param opts? Dap.Config|table
---@return boolean success
function M.setup(opts)
  if M._initialized then
    require("dap_nvim.utils.notify").warn("Already initialized")
    return false
  end

  local config = require("dap_nvim.config")
  local cfg = config.setup(opts)
  M._config = cfg

  local ok_core, core = pcall(require, "dap_nvim.core")
  if not ok_core then
    require("dap_nvim.utils.notify").error("Failed to load core module")
    return false
  end

  local ok_init, err = pcall(core.setup, cfg)
  if not ok_init then
    require("dap_nvim.utils.notify").error(string.format("Core initialization failed: %s", err))
    return false
  end

  local ok_adapters, adapters_mod = pcall(require, "dap_nvim.adapters")
  if ok_adapters and type(adapters_mod.register_all) == "function" then
    local adapter_ok, adapter_err = pcall(adapters_mod.register_all, cfg.languages, cfg.adapters or {})
    if not adapter_ok then
      require("dap_nvim.utils.notify").warn(string.format("Adapter registration failed: %s", adapter_err))
    end
  end

  local ok_configs, configurations_mod = pcall(require, "dap_nvim.configurations")
  if ok_configs and type(configurations_mod.load_all) == "function" then
    local config_ok, config_err = pcall(configurations_mod.load_all, cfg.languages, cfg.configurations or {})
    if not config_ok then
      require("dap_nvim.utils.notify").warn(string.format("Configuration loading failed: %s", config_err))
    end
  end

  local ok_ui, ui_mod = pcall(require, "dap_nvim.ui")
  if ok_ui then
    pcall(ui_mod.setup, cfg.ui)
  end

  require("dap_nvim.bindings").setup(cfg)

  M._initialized = true
  vim.g.loaded_dap_nvim = 1

  return true
end

--- Get current configuration
---@return Dap.Config|nil
function M.get_config()
  return M._config
end

--- Check if dap.nvim is initialized
---@return boolean
function M.is_initialized()
  return M._initialized
end

--- Get available languages
---@return string[]
function M.available_languages()
  local ok, registry = pcall(require, "dap_nvim.registry")
  if ok then
    return registry.available_languages()
  end
  return {}
end

--- Get enabled languages
---@return string[]
function M.enabled_languages()
  local ok, registry = pcall(require, "dap_nvim.registry")
  if ok then
    return registry.enabled_languages()
  end
  return {}
end

return M
