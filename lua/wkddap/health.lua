---@module 'wkddap.health'
--- :checkhealth wkddap — environment, lib.nvim deps, adapters, externals.

local check_require = require("lib.nvim.health").check_require

local M = {}

function M.check()
  -- ── Core ────────────────────────────────────────────────────────────────
  vim.health.start("dap.nvim: core")
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.warn("Neovim 0.9+ recommended", { "Upgrade Neovim to 0.9+" })
  end

  if pcall(require, "dap") then
    vim.health.ok("nvim-dap installed")
  else
    vim.health.error(
      "nvim-dap (mfussenegger/nvim-dap) not found — required dependency",
      { 'Install "mfussenegger/nvim-dap"' }
    )
  end

  if vim.g.loaded_wkddap then
    vim.health.ok("plugin loaded (vim.g.loaded_wkddap = " .. tostring(vim.g.loaded_wkddap) .. ")")
  else
    vim.health.info("plugin not yet initialized — call require('dap').setup()")
  end

  -- ── lib.nvim dependency ───────────────────────────────────────────────────
  vim.health.start("dap.nvim: lib.nvim")
  -- All three are required unconditionally, with no pcall anywhere they are
  -- actually used (wkddap.core and friends) -- including inside the error
  -- path itself (wkddap.utils.notify wraps lib.nvim.notify), so lib.nvim
  -- absent means setup() fails outright, not a graceful per-feature
  -- degradation. "warn" was under-reporting a hard dependency.
  local advice = { 'Install "StefanBartl/lib.nvim"' }
  check_require("lib.nvim.notify", "notify", "error", advice)
  check_require("lib.nvim.cross", "cross (platform detection)", "error", advice)
  check_require("lib.nvim.normalize", "normalize (path helpers)", "error", advice)
  if pcall(require, "lib.nvim.bindings.keymap") then
    vim.health.ok("lib.nvim.bindings.keymap available (enhanced keymaps)")
  else
    vim.health.info("lib.nvim.bindings.keymap not found — using vim.keymap.set fallback")
  end

  -- ── UI companions ─────────────────────────────────────────────────────────
  vim.health.start("dap.nvim: UI companions")
  local ui_opts = require("wkddap.config").get().ui or {}
  local preference = ui_opts.provider or "dap-view"
  local has_view = pcall(require, "dap-view")
  local has_dapui = pcall(require, "dapui")

  vim.health.info("ui.provider = " .. tostring(preference))

  if has_view then
    vim.health.ok("nvim-dap-view installed (default panel UI)")
  else
    vim.health.info("nvim-dap-view not found (optional)")
  end

  if has_dapui then
    vim.health.ok("nvim-dap-ui installed (opt-in via ui.provider = 'dap-ui')")
  else
    vim.health.info("nvim-dap-ui not found (optional)")
  end

  local active = require("wkddap.ui.provider").active()
  if active then
    vim.health.ok("active panel UI: " .. active)
    if preference ~= "auto" and preference ~= active then
      vim.health.warn(
        string.format("'%s' is not installed — fell back to '%s'", preference, active),
        { string.format("Install '%s', or set ui.provider = '%s'", preference, active) }
      )
    end
  elseif preference == "none" or not ui_opts.enable then
    vim.health.info("panel UI disabled by configuration")
  else
    vim.health.warn("no panel UI active", { "Install nvim-dap-view or nvim-dap-ui" })
  end

  if pcall(require, "nvim-dap-virtual-text") then
    vim.health.ok("nvim-dap-virtual-text installed")
  else
    vim.health.info("nvim-dap-virtual-text not found (optional)")
  end

  if pcall(require, "which-key") then
    vim.health.ok("which-key present (keymap group label)")
  else
    vim.health.info("which-key not installed (optional)")
  end

  -- ── Language adapters ─────────────────────────────────────────────────────
  vim.health.start("dap.nvim: language adapters")
  local config = require("wkddap.config")
  local registry = require("wkddap.registry")

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

  -- ── Registry ───────────────────────────────────────────────────────────────
  vim.health.start("dap.nvim: registry")
  local stats = registry.stats()
  vim.health.info(
    string.format(
      "available: %d, registered: %d, enabled: %d",
      stats.available,
      stats.registered,
      stats.enabled
    )
  )

  local valid, errors = registry.validate()
  if valid then
    vim.health.ok("all enabled adapters still valid")
  else
    for _, err in ipairs(errors) do
      vim.health.warn(err)
    end
  end

  -- ── composer route pre-flight ─────────────────────────────────────────────
  require("lib.nvim.bindings.usercmd.composer").checkhealth("Dap")
end

return M
