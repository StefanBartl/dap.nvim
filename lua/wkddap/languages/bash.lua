---@module 'wkddap.languages.bash'
--- Shell scripts: adapter (bash-debug-adapter) + launch configuration.
---
--- Ported from the nvim config's dead `lsp/debug_adapters/bash.lua`, which
--- registered `dap.adapters`/`dap.configurations` at module load and was never
--- required by anything. Here it follows the registry's contract: `setup()`
--- registers the adapter, `load()` the configurations, and the binary is
--- resolved through `config.get_adapter_path` instead of a bare
--- `vim.fn.exepath` at load time.

local config = require("wkddap.config")

local M = {}

---@return boolean success
function M.setup()
  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  local adapter_path = config.get_adapter_path("bash")
  if not adapter_path then
    return false
  end

  dap.adapters.bashdb = {
    type = "executable",
    command = adapter_path,
    args = {},
  }

  return true
end

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  local configurations = {
    {
      type = "bashdb",
      request = "launch",
      name = "Debug current shell script",
      program = "${file}",
      cwd = "${workspaceFolder}",
      -- `pathBash` must point at a real bash: the adapter shells out to it.
      -- `pathBashdb`/`pathBashdbLib` stay empty so the adapter falls back to
      -- the copy it bundles, which is the working default on machines that do
      -- not have bashdb installed separately (Windows in particular).
      pathBash = vim.fn.exepath("bash"),
      pathBashdb = vim.fn.exepath("bashdb"),
      pathBashdbLib = "",
      trace = false,
      args = {},
      env = {},
      terminalKind = "integrated",
    },
  }

  -- One configuration list, three filetypes. bashdb only really understands
  -- bash, but a zsh/ksh script that stays inside the common subset debugs
  -- fine, and refusing to offer it would be less useful than letting it fail
  -- on a shell-specific construct.
  for _, ft in ipairs({ "sh", "bash", "zsh", "ksh" }) do
    dap.configurations[ft] = vim.deepcopy(configurations)
  end

  return true
end

return M
