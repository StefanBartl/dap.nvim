---@module 'wkddap.adapters'
--- Registers adapters (dap.adapters.*) for the requested languages via
--- registry.register(), which requires each language's
--- `wkddap.languages.<lang>` module and calls its `setup()`.

local notify = require("lib.nvim.notify").create("[dap.nvim.adapters]")

local M = {}

--- Register all adapters for specified languages
---@param languages string[] List of languages
---@param _custom_adapters table? Custom adapter overrides (reserved for future use)
---@return boolean success
function M.register_all(languages, _custom_adapters)
  local registry = require("wkddap.registry")

  if not languages or #languages == 0 then
    languages = registry.available_languages()
  end

  local failed = {}
  for _, lang in ipairs(languages) do
    local ok = registry.register(lang)
    if not ok then
      failed[#failed + 1] = lang
    end
  end

  -- One summary notification instead of one per language: with every
  -- adapter missing (a fresh machine, nothing installed via Mason yet) this
  -- used to fire a warning per language on every startup. The per-language
  -- reason is still available -- :checkhealth wkddap re-validates each one.
  if #failed > 0 then
    table.sort(failed)
    notify.warn(
      string.format(
        "%d/%d adapter(s) unavailable: %s -- see :checkhealth wkddap for details",
        #failed,
        #languages,
        table.concat(failed, ", ")
      )
    )
  end

  return true
end

return M
