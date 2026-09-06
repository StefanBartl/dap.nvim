---@module 'wkddap.languages.csharp'
--- .NET (C#, F#): adapter (netcoredbg) + launch configuration.
---
--- Ported from the nvim config's dead `lsp/debug_adapters/dotnet.lua`. Two
--- things changed on the way in:
---
--- - The adapter path was hardcoded to
---   `C:/tools/DebugAdapterProtocol/netcoredbg/netcoredbg.exe`, i.e. to one
---   machine. It now resolves through `config.get_adapter_path`, which finds
---   the Mason package (`netcoredbg`) or a `$PATH` install.
--- - `set noshellslash` ran at module load, as a global side effect of merely
---   requiring the file. It now runs in `setup()`, only on Windows, and only
---   when this adapter is actually being registered.

local config = require("wkddap.config")
local paths = require("wkddap.utils.paths")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("csharp")
  if not adapter_path then
    return false
  end

  -- netcoredbg receives the DLL path as a plain argument. With 'shellslash'
  -- set, Vim hands it forward slashes, which the adapter rejects on Windows.
  -- Scoped to the moment the adapter is registered rather than to "this file
  -- was required at all".
  if vim.fn.has("win32") == 1 then
    vim.opt.shellslash = false
  end

  dap.adapters.coreclr = {
    type = "executable",
    command = adapter_path,
    args = { "--interpreter=vscode" },
  }

  return true
end

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  for _, ft in ipairs({ "cs", "fsharp" }) do
    dap.configurations[ft] = {
      {
        type = "coreclr",
        name = "Launch - netcoredbg",
        request = "launch",
        -- Async prompt via nvim-dap's coroutine.wrap() config resolution; see
        -- docs/FEATURES/LANGUAGES.md.
        program = function()
          local co = coroutine.running()
          require("lib.nvim.ui.kit").input({
            -- Defaulting into `bin/Debug/` rather than the project root: that
            -- is where the DLL actually lands, and typing the framework
            -- directory by hand every run is the whole friction here.
            title = "Path to DLL: ",
            default = paths.join(vim.fn.getcwd(), "bin", "Debug", ""),
            completion = "file",
            on_submit = function(input)
              coroutine.resume(co, input)
            end,
            on_cancel = function()
              coroutine.resume(co, "")
            end,
          })
          return paths.normalize(coroutine.yield())
        end,
        cwd = "${workspaceFolder}",
      },
    }
  end

  return true
end

return M
