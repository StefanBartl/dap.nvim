---@module 'dap.configurations'
---@brief Loads launch configurations (dap.configurations.*) for the requested languages.

local notify = require("lib.nvim.notify").create("[dap.nvim.configurations]")

local M = {}

--- Load all configurations for specified languages
---@param languages string[] List of languages
---@param custom_configs table? Custom configuration overrides, keyed by language
---@return boolean success
function M.load_all(languages, custom_configs)
  local config = require("dap.config")

  if not languages or #languages == 0 then
    local registry = require("dap.registry")
    languages = registry.available_languages()
  end

  for _, lang in ipairs(languages) do
    local actual_lang = config.language_aliases[lang] or lang

    local config_module = string.format("dap.configurations.%s", actual_lang)
    local ok, mod = pcall(require, config_module)

    if ok and type(mod.load) == "function" then
      local load_ok, load_err = pcall(mod.load)
      if not load_ok then
        notify.warn(string.format("Failed to load %s: %s", lang, load_err or "unknown"))
      end
    end
  end

  if custom_configs and next(custom_configs) then
    local dap = require("dap")
    for lang, configs in pairs(custom_configs) do
      if dap.configurations[lang] then
        vim.list_extend(dap.configurations[lang], configs)
      else
        dap.configurations[lang] = configs
      end
    end
  end

  return true
end

return M
