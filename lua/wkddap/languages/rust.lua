---@module 'dap.languages.rust'
---@brief Rust: adapter (CodeLLDB) + launch configurations (with rustc
---@brief pretty-printer setup)

local config = require("wkddap.config")
local paths = require("wkddap.utils.paths")

local M = {}

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
      program = function()
        return paths.normalize(
          vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
        )
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      initCommands = function()
        local rustc_sysroot = vim.fn.trim(
          vim.system({ "rustc", "--print", "sysroot" }, { text = true }):wait().stdout or ""
        )
        local script_import = 'command script import "'
          .. rustc_sysroot
          .. '/lib/rustlib/etc/lldb_lookup.py"'
        local commands_file = rustc_sysroot .. "/lib/rustlib/etc/lldb_commands"
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
