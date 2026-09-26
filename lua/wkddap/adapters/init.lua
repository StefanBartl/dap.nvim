---@module 'wkddap.adapters'
--- Registers adapters (dap.adapters.*) for the requested languages via
--- registry.register(), which requires each language's
--- `wkddap.languages.<lang>` module and calls its `setup()`.

local M = {}

--- Languages the last `register_all` could not register (their adapter binary
--- was not found), sorted. Read by whoever wants the reason -- :checkhealth
--- wkddap re-validates each one -- instead of a notification at every startup.
---@type string[]
M.unavailable = {}

--- Register all adapters for specified languages
---@param languages string[] List of languages
---@param custom_adapters table<string, table|function>? Overrides keyed by
---  nvim-dap adapter name (`codelldb`, `pwa-node`, ...), applied after the
---  language modules registered theirs: a table is deep-merged over the
---  built-in definition, a function (or a name nothing registered) replaces
---  resp. adds the adapter as given.
---@return boolean success
function M.register_all(languages, custom_adapters)
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

  if custom_adapters and next(custom_adapters) then
    local dap = require("dap")
    for name, override in pairs(custom_adapters) do
      local existing = dap.adapters[name]
      if type(existing) == "table" and type(override) == "table" then
        dap.adapters[name] = vim.tbl_deep_extend("force", existing, override)
      else
        dap.adapters[name] = override
      end
    end
  end

  -- No notification. A missing adapter is not an error -- that language is
  -- simply not wired, as docs/FEATURES/LANGUAGES.md says -- and it used to be
  -- announced on EVERY startup ("12/13 adapter(s) unavailable"): the summary
  -- replaced one warning per language, but for someone who debugs one language
  -- it was still noise each time. The list is kept in `M.unavailable` and
  -- :checkhealth wkddap re-validates each language and says why.
  table.sort(failed)
  M.unavailable = failed

  return true
end

return M
