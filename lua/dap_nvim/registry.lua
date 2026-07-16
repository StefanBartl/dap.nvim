---@module 'dap_nvim.registry'
---@brief Language adapter registry with validation and lifecycle management.

local config = require("dap_nvim.config")
local notify = require("lib.nvim.notify").create("[dap.nvim.registry]")

local M = {}

---@type table<string, boolean>
local _registered = {}

---@type table<string, boolean>
local _enabled = {}

--- All supported languages
---@type string[]
local SUPPORTED_LANGUAGES = {
  "lua",
  "javascript",
  "typescript",
  "c",
  "cpp",
  "go",
  "python",
  "rust",
  "zig",
  "assembly",
}

--- Register a language adapter
---@param language string Language identifier
---@return boolean success
---@return string? error_message
function M.register(language)
  if _registered[language] then
    return true, nil
  end

  local actual_lang = config.language_aliases[language] or language

  local valid, err = config.validate_adapter(actual_lang)
  if not valid then
    notify.warn(err or ("unknown adapter: " .. actual_lang))
    return false, err
  end

  local adapter_module = string.format("dap_nvim.adapters.%s", actual_lang)
  local ok, adapter = pcall(require, adapter_module)
  if not ok then
    local msg = string.format("Failed to load adapter module: %s", adapter_module)
    notify.error(msg)
    return false, msg
  end

  if type(adapter.setup) == "function" then
    local setup_ok, setup_err = pcall(adapter.setup)
    if not setup_ok then
      local msg = string.format("Adapter setup failed for %s: %s", actual_lang, setup_err)
      notify.error(msg)
      return false, msg
    end
  end

  _registered[language] = true
  _enabled[actual_lang] = true

  return true, nil
end

--- Unregister a language adapter
---@param language string Language identifier
---@return boolean success
function M.unregister(language)
  if not _registered[language] then
    return false
  end

  local actual_lang = config.language_aliases[language] or language
  _registered[language] = nil
  _enabled[actual_lang] = nil

  notify.info(string.format("Unregistered: %s", language))
  return true
end

---@param language string
---@return boolean
function M.is_registered(language)
  return _registered[language] == true
end

---@param language string
---@return boolean
function M.is_enabled(language)
  local actual_lang = config.language_aliases[language] or language
  return _enabled[actual_lang] == true
end

---@return string[]
function M.available_languages()
  return vim.deepcopy(SUPPORTED_LANGUAGES)
end

---@return string[]
function M.registered_languages()
  local langs = {}
  for lang, _ in pairs(_registered) do
    table.insert(langs, lang)
  end
  table.sort(langs)
  return langs
end

--- Get all enabled languages (resolved via aliases)
---@return string[]
function M.enabled_languages()
  local langs = {}
  for lang, _ in pairs(_enabled) do
    table.insert(langs, lang)
  end
  table.sort(langs)
  return langs
end

--- Register multiple languages
---@param languages string[] List of languages to register (empty = all available)
---@return table<string, boolean> success_map
function M.register_all(languages)
  local results = {}

  if not languages or #languages == 0 then
    languages = SUPPORTED_LANGUAGES
  end

  for _, lang in ipairs(languages) do
    local ok, err = M.register(lang)
    results[lang] = ok
    if not ok then
      notify.warn(string.format("Skipped %s: %s", lang, err or "unknown error"))
    end
  end

  return results
end

--- Validate registry state
---@return boolean all_valid
---@return string[] errors
function M.validate()
  local errors = {}

  for lang, _ in pairs(_enabled) do
    local valid, err = config.validate_adapter(lang)
    if not valid then
      table.insert(errors, string.format("%s: %s", lang, err))
    end
  end

  return #errors == 0, errors
end

--- Get registry statistics
---@return table stats
function M.stats()
  return {
    available = #SUPPORTED_LANGUAGES,
    registered = vim.tbl_count(_registered),
    enabled = vim.tbl_count(_enabled),
  }
end

return M
