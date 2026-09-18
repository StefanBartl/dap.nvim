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
---   requiring the file -- and later from `setup()`, still session-wide,
---   overriding whatever the user had chosen for every other plugin. The
---   option is no longer touched at all: the two paths netcoredbg receives
---   (`program`, `cwd`) are converted to native separators right where they
---   are produced.

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
          local co = assert(coroutine.running(), "program() must run inside a coroutine")
          require("ui.kit").input({
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
          -- netcoredbg rejects forward-slash paths on Windows; converting
          -- here (and for cwd below) is what `set noshellslash` used to do
          -- for the whole session.
          return paths.native(paths.normalize(coroutine.yield()))
        end,
        -- What "${workspaceFolder}" expands to, with native separators.
        cwd = function()
          return paths.native(vim.fn.getcwd())
        end,
      },
    }
  end

  return true
end

return M
