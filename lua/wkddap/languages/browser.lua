---@module 'wkddap.languages.browser'
--- Browser debugging: adapter (js-debug `pwa-chrome`) + attach/launch
--- configurations for JavaScript, TypeScript and Astro.
---
--- Ported from the nvim config's dead `lsp/debug_adapters/webdev/browser`.
--- Registered as its own "language" rather than folded into `javascript.lua`
--- because it is a separate decision: node debugging and browser debugging use
--- the same Mason package but answer different questions, and someone who
--- wants one does not necessarily want the other in their configuration list.
---
--- Attaching needs the browser started with remote debugging enabled: >
---     google-chrome --remote-debugging-port=9222
--- <
--- The same applies to other Chromium browsers (Brave, Edge). When breakpoints
--- do not bind, `webRoot` is usually the culprit -- it has to point at the
--- directory the served source maps are relative to.

local config = require("wkddap.config")

local M = {}

--- Filetypes that get the browser configurations. Astro is in the list because
--- its `<script>` blocks compile to the same JS the browser serves.
---@type string[]
local FILETYPES = { "javascript", "typescript", "javascriptreact", "typescriptreact", "astro" }

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  -- Same Mason package as the node adapter -- js-debug ships one server that
  -- speaks both -- but its own `adapter_binaries` entry, so enabling browser
  -- debugging does not silently depend on `javascript` being in the list.
  if not config.get_adapter_path("browser") then
    return false
  end

  local adapter_script = vim.fn.stdpath("data")
    .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"

  dap.adapters["pwa-chrome"] = {
    type = "server",
    port = "${port}",
    executable = {
      command = "node",
      args = { adapter_script, "${port}" },
    },
  }

  return true
end

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  ---@type table[]
  local browser_configs = {
    {
      type = "pwa-chrome",
      request = "attach",
      name = "Attach to Chrome (js-debug)",
      port = 9222,
      webRoot = "${workspaceFolder}",
    },
    {
      type = "pwa-chrome",
      request = "launch",
      name = "Launch Chrome (js-debug)",
      url = "http://localhost:3000",
      webRoot = "${workspaceFolder}",
    },
  }

  -- Appended, not assigned: `javascript.lua` owns the node configurations for
  -- the same filetypes, and whichever of the two loads second must not drop
  -- the other's entries.
  --- CDX: javascript.lua's load() *assigns* dap.configurations[ft], it does not
  --- append. So this contract only holds in the default load order (javascript
  --- before browser in registry.SUPPORTED_LANGUAGES); `languages = { "browser",
  --- "javascript" }` wipes these browser configs.
  for _, ft in ipairs(FILETYPES) do
    dap.configurations[ft] = dap.configurations[ft] or {}
    vim.list_extend(dap.configurations[ft], vim.deepcopy(browser_configs))
  end

  return true
end

return M
