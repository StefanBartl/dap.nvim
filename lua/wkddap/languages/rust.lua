---@module 'wkddap.languages.rust'
--- Rust: adapter (CodeLLDB) + launch configurations (with rustc
--- pretty-printer setup)

local config = require("wkddap.config")
local paths = require("wkddap.utils.paths")
local executable = require("wkddap.utils.executable")

local M = {}

---@internal
---`rustc --print sysroot`, keyed by the directory it ran in. Not one value
---per session: a `rust-toolchain.toml` or `rustup override` makes the answer
---depend on the working directory, so a `:cd` into another project must not
---keep serving the first project's toolchain. Only successful lookups are
---stored -- a missing or failing rustc is re-checked at the next session
---start instead of being remembered as an empty sysroot.
---@type table<string, string>
local sysroot_cache = {}

---@internal
---Store a successful lookup for `cwd`; a failure or empty answer stores nothing.
---@param cwd string
---@param res { code: integer, stdout: string|nil }
---@return nil
local function remember_sysroot(cwd, res)
  -- vim.trim, not vim.fn.trim: this also runs from a vim.system callback,
  -- a fast-event context where Vimscript functions raise E5560.
  local sysroot = res.code == 0 and res.stdout and vim.trim(res.stdout) or ""
  if sysroot ~= "" then
    sysroot_cache[cwd] = sysroot
  end
end

---@internal
---Warm the cache for the current directory in the background.
---
---`initCommands` below needs the sysroot to point LLDB at Rust's
---pretty-printers, and used to obtain it with `vim.system(...):wait()` --
---blocking the editor on every debug session start. Prefetching it when the
---language module loads means the value is virtually always there by the time
---a session actually starts; the blocking call survives only as the fallback
---for the race where it is not, or for a session started from another
---directory than the prefetch ran in.
---@return nil
local function prefetch_sysroot()
  local cwd = paths.workspace_root()
  if sysroot_cache[cwd] or not executable.exists("rustc") then
    return
  end
  pcall(vim.system, { "rustc", "--print", "sysroot" }, { text = true, cwd = cwd }, function(res)
    remember_sysroot(cwd, res)
  end)
end

---@internal
---@return string|nil sysroot  nil when rustc is unavailable or gave no answer
local function rustc_sysroot()
  local cwd = paths.workspace_root()
  if sysroot_cache[cwd] then
    return sysroot_cache[cwd]
  end
  if not executable.exists("rustc") then
    return nil
  end
  -- Fallback only: the prefetch above has not landed yet.
  local ok, proc = pcall(vim.system, { "rustc", "--print", "sysroot" }, { text = true, cwd = cwd })
  if ok then
    remember_sysroot(cwd, proc:wait())
  end
  return sysroot_cache[cwd]
end

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("rust")
  if not adapter_path then
    return false
  end

  dap.adapters.codelldb = dap.adapters.codelldb
    or {
      type = "server",
      port = "${port}",
      executable = {
        command = adapter_path,
        args = { "--port", "${port}" },
      },
    }

  prefetch_sysroot()

  return true
end

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  dap.configurations.rust = {
    {
      name = "Launch",
      type = "codelldb",
      request = "launch",
      -- Async prompt via nvim-dap's coroutine.wrap() config resolution; see
      -- docs/FEATURES/LANGUAGES.md.
      program = function()
        local co = assert(coroutine.running(), "program() must run inside a coroutine")
        require("ui.kit").input({
          title = "Path to executable: ",
          default = paths.join(vim.fn.getcwd(), "target", "debug", ""),
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
      stopOnEntry = false,
      initCommands = function()
        local sysroot = rustc_sysroot()
        if not sysroot then
          -- No toolchain to borrow the pretty-printers from. Plain LLDB
          -- output beats an import error for a path rooted at "/" whose
          -- text never mentions the actual cause.
          vim.notify(
            "rustc not found -- starting without Rust's LLDB pretty-printers",
            vim.log.levels.WARN
          )
          return {}
        end
        local script_import = 'command script import "'
          .. sysroot
          .. '/lib/rustlib/etc/lldb_lookup.py"'
        local commands_file = sysroot .. "/lib/rustlib/etc/lldb_commands"
        local commands = {}
        local file = io.open(commands_file, "r")
        if file then
          for line in file:lines() do
            table.insert(commands, line)
          end
          file:close()
        end
        table.insert(commands, 1, script_import)
        return commands
      end,
    },
  }

  return true
end

return M
