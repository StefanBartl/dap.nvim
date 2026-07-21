---@module 'dap.adapters'
---@brief Registers adapters (dap.adapters.*) for the requested languages.

local notify = require("lib.nvim.notify").create("[dap.nvim.adapters]")

local M = {}

--- Register all adapters for specified languages
---@param languages string[] List of languages
---@param custom_adapters table? Custom adapter overrides (reserved for future use)
---@return boolean success
---@diagnostic disable-next-line: unused-local
function M.register_all(languages, custom_adapters)
  local registry = require("dap.registry")

  if not languages or #languages == 0 then
    languages = registry.available_languages()
  end

  for _, lang in ipairs(languages) do
    local ok, err = registry.register(lang)
    if not ok then
      notify.warn(string.format("Failed to register %s: %s", lang, err or "unknown"))
    end
  end

  return true
end

return M
