---@module 'dap.utils.mason'
---@brief Drives `:MasonInstall` for required adapter binaries that are
---@brief currently unresolvable, when `auto_install` is enabled.

local notify = require("lib.nvim.notify").create("[dap.nvim.mason]")

local M = {}

--- Install any required, Mason-backed adapters that aren't currently
--- resolvable (not on PATH, not already under mason/bin).
---@param languages string[] Languages being set up (empty = all available)
function M.ensure_installed(languages)
  if not pcall(require, "mason") then
    notify.warn("auto_install is enabled but mason.nvim is not installed")
    return
  end

  local config = require("wkddap.config")

  if not languages or #languages == 0 then
    languages = require("wkddap.registry").available_languages()
  end

  local missing = {}
  for _, lang in ipairs(languages) do
    local actual_lang = config.language_aliases[lang] or lang
    local adapter = config.adapter_binaries[actual_lang]
    if adapter and adapter.type == "binary" and adapter.mason_pkg then
      if not config.get_adapter_path(actual_lang) then
        missing[adapter.mason_pkg] = true
      end
    end
  end

  local pkgs = vim.tbl_keys(missing)
  if #pkgs == 0 then
    return
  end

  table.sort(pkgs)
  notify.info(string.format("auto_install: installing via Mason: %s", table.concat(pkgs, ", ")))
  vim.cmd("MasonInstall " .. table.concat(pkgs, " "))
end

return M
