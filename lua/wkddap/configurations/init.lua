---@module 'dap.configurations'
---@brief Loads launch configurations (dap.configurations.*) for the requested
---@brief languages, by requiring each language's `wkddap.languages.<lang>`
---@brief module and calling its `load()`.

local notify = require("lib.nvim.notify").create("[dap.nvim.configurations]")

local M = {}

--- Load all configurations for specified languages
---@param languages string[] List of languages
---@param custom_configs table? Custom configuration overrides, keyed by
---  language. Each value is a list of dap config entries; by default it is
---  appended to the language's existing configurations. Set `replace = true`
---  alongside the entries to replace instead:
---  `{ replace = true, { type = "python", request = "launch", name = "…" } }`
---@return boolean success
function M.load_all(languages, custom_configs)
  local config = require("wkddap.config")

  if not languages or #languages == 0 then
    local registry = require("wkddap.registry")
    languages = registry.available_languages()
  end

  for _, lang in ipairs(languages) do
    local actual_lang = config.language_aliases[lang] or lang

    local config_module = string.format("wkddap.languages.%s", actual_lang)
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
      local replace = configs.replace == true
      local entries = {}
      for _, entry in ipairs(configs) do
        table.insert(entries, entry)
      end

      if replace or not dap.configurations[lang] then
        dap.configurations[lang] = entries
      else
        vim.list_extend(dap.configurations[lang], entries)
      end
    end
  end

  return true
end

return M
