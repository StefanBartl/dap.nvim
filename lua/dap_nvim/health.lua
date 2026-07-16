---@module 'dap_nvim.health'
---@brief :checkhealth dap_nvim — environment, lib.nvim deps, adapters, externals.

local M = {}

---@param mod string
---@param label string
---@param level "ok"|"warn"|"info"
local function check_require(mod, label, level)
  if pcall(require, mod) then
    vim.health.ok(label .. " (" .. mod .. ")")
  elseif level == "warn" then
    vim.health.warn(label .. " missing (" .. mod .. ")")
  else
    vim.health.info(label .. " not found (" .. mod .. ")")
  end
end

function M.check()
  -- ── Core ────────────────────────────────────────────────────────────────
  vim.health.start("dap.nvim: core")
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.warn("Neovim 0.9+ recommended")
  end

  if pcall(require, "dap") then
    vim.health.ok("nvim-dap installed")
  else
    vim.health.error("nvim-dap (mfussenegger/nvim-dap) not found — required dependency")
  end

  if vim.g.loaded_dap_nvim then
    vim.health.ok("plugin loaded (vim.g.loaded_dap_nvim = " .. tostring(vim.g.loaded_dap_nvim) .. ")")
  else
    vim.health.info("plugin not yet initialized — call require('dap_nvim').setup()")
  end

  -- ── lib.nvim dependency ───────────────────────────────────────────────────
  vim.health.start("dap.nvim: lib.nvim")
  check_require("lib.nvim.notify", "notify", "warn")
  check_require("lib.nvim.cross", "cross (platform detection)", "warn")
  check_require("lib.nvim.normalize", "normalize (path helpers)", "warn")

  -- ── UI companions ─────────────────────────────────────────────────────────
  vim.health.start("dap.nvim: UI companions")
  if pcall(require, "dapui") then
    vim.health.ok("nvim-dap-ui installed")
  else
    vim.health.warn("nvim-dap-ui not found (recommended for rich debugging UI)")
  end

  if pcall(require, "nvim-dap-virtual-text") then
    vim.health.ok("nvim-dap-virtual-text installed")
  else
    vim.health.info("nvim-dap-virtual-text not found (optional)")
  end

  if require("dap_nvim.bindings.which_key").available() then
    vim.health.ok("which-key present (keymap group label)")
  else
    vim.health.info("which-key not installed (optional)")
  end

  -- ── Language adapters ─────────────────────────────────────────────────────
  vim.health.start("dap.nvim: language adapters")
  local config = require("dap_nvim.config")
  local registry = require("dap_nvim.registry")

  for _, lang in ipairs(registry.available_languages()) do
    -- Resolve aliases (typescript -> javascript, cpp -> c, ...) before
    -- validating; adapter_binaries is keyed by the canonical name only.
    local actual_lang = config.language_aliases[lang] or lang
    local valid, err = config.validate_adapter(actual_lang)
    if valid then
      vim.health.ok(string.format("%s: adapter available", lang))
    else
      vim.health.info(string.format("%s: %s", lang, err))
    end
  end

  -- ── Enabled languages ──────────────────────────────────────────────────────
  vim.health.start("dap.nvim: configuration")
  local enabled = registry.enabled_languages()
  if #enabled > 0 then
    vim.health.ok(string.format("Enabled languages: %s", table.concat(enabled, ", ")))
  else
    vim.health.info("No languages enabled yet")
  end
end

return M
