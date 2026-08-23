---@module 'wkddap.registry'
--- Language adapter registry with validation and lifecycle management.

local config = require("wkddap.config")
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
  "bash",
  "csharp",
  -- Not a language: browser debugging over js-debug's `pwa-chrome`. It is in
  -- this list because it is an independently selectable adapter with its own
  -- binary requirement, not because "browser" is a filetype.
  "browser",
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
    return false, err or ("unknown adapter: " .. actual_lang)
  end

  local adapter_module = string.format("wkddap.languages.%s", actual_lang)
  local ok, adapter = pcall(require, adapter_module)
  if not ok then
    return false, string.format("Failed to load adapter module: %s", adapter_module)
  end

  if type(adapter.setup) == "function" then
    local setup_ok, setup_err = pcall(adapter.setup)
    if not setup_ok then
      return false, string.format("Adapter setup failed for %s: %s", actual_lang, setup_err)
    end
  end

  _registered[language] = true
  _enabled[actual_lang] = true

  return true, nil
end

--- Unregister a language adapter
---
--- Low-level status-only op (see Refactoring "fail late"): callers decide
--- whether/how to report the outcome to the user.
---@param language string Language identifier
---@return boolean success
function M.unregister(language)
  if not _registered[language] then
    return false
  end

  local actual_lang = config.language_aliases[language] or language
  _registered[language] = nil
  _enabled[actual_lang] = nil

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

--- Register multiple languages.
---
--- Unlike `register()`, this is itself a user-facing aggregation entry point
--- (there is no other wrapper reporting per-item failures for this path), so
--- it notifies per skipped language in addition to returning the results.
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
