---@module 'wkddap.languages.rust'
--- Rust: adapter (CodeLLDB) + launch configurations (with rustc
--- pretty-printer setup)

local config = require("wkddap.config")
local paths = require("wkddap.utils.paths")
local executable = require("wkddap.utils.executable")

local M = {}

---@internal
---Cached `rustc --print sysroot`. The value is a property of the toolchain,
---not of the session, so once is enough.
---@type string|nil
local sysroot_cache = nil

---@internal
---Warm `sysroot_cache` in the background.
---
---`initCommands` below needs the sysroot to point LLDB at Rust's
---pretty-printers, and used to obtain it with `vim.system(...):wait()` --
---blocking the editor on every debug session start. Prefetching it when the
---language module loads means the value is virtually always there by the time
---a session actually starts; the blocking call survives only as the fallback
---for the race where it is not.
---@return nil
local function prefetch_sysroot()
  if sysroot_cache or not executable.exists("rustc") then
    return
  end
  vim.system({ "rustc", "--print", "sysroot" }, { text = true }, function(res)
    -- vim.system-Callbacks laufen in einem Fast-Event-Context: `vim.fn.trim`
    -- ist eine Vimscript-Funktion und wirft dort E5560. `vim.trim` ist reines
    -- Lua und damit hier erlaubt.
    if res.code == 0 and res.stdout and res.stdout ~= "" then
      sysroot_cache = vim.trim(res.stdout)
    end
  end)
end

---@internal
---@return string sysroot  empty string when rustc is unavailable
local function rustc_sysroot()
  if sysroot_cache then
    return sysroot_cache
  end
  if not executable.exists("rustc") then
    return ""
  end
  -- Fallback only: the prefetch above has not landed yet.
  sysroot_cache =
    vim.trim(vim.system({ "rustc", "--print", "sysroot" }, { text = true }):wait().stdout or "")
  return sysroot_cache
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
      -- nvim-dap resolves config functions inside coroutine.wrap(), so an
      -- async prompt works via the same yield/resume idiom nvim-dap's own
      -- async pickers use: yield, let kit.input's on_submit resume the
      -- suspended coroutine with the typed value.
      program = function()
        local co = coroutine.running()
        require("lib.nvim.ui.kit").input({
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
