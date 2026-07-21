---@module 'dap.config'
---@brief Runtime configuration store, plus adapter/binary metadata for dap.nvim.
---@description
--- Merges user options over the immutable DEFAULTS and exposes the active
--- config via `get()`. Also carries the static per-language adapter/binary
--- table (Mason package names, UI signs/highlights/layout) consumed by the
--- registry, adapters, and UI modules.

local DEFAULTS = require("wkddap.config.DEFAULTS")
local cross = require("lib.nvim.cross")

local M = {}

---@type Dap.Config|nil
local _active = nil

--- Merge user options over the defaults and store the result.
---@param user_opts? Dap.Config|table
---@return Dap.Config
function M.setup(user_opts)
  if type(user_opts) ~= "table" then
    user_opts = {}
  end

  ---@diagnostic disable-next-line: missing-fields
  _active = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), user_opts)
  return _active
end

---@return Dap.Config
function M.get()
  if _active == nil then
    _active = vim.deepcopy(DEFAULTS)
  end
  return _active
end

--- Default adapter binaries and their Mason package names
---@type table<string, {binary?: string, mason_pkg?: string, required?: boolean, type: 'binary'|'plugin'}>
M.adapter_binaries = {
  lua = { type = "plugin", binary = "osv", required = false },
  javascript = { type = "binary", binary = "js-debug-adapter", mason_pkg = "js-debug-adapter", required = true },
  go = { type = "binary", binary = "dlv", mason_pkg = "delve", required = true },
  python = { type = "binary", binary = "debugpy", mason_pkg = "debugpy", required = true },
  c = { type = "binary", binary = "codelldb", mason_pkg = "codelldb", required = true },
  rust = { type = "binary", binary = "codelldb", mason_pkg = "codelldb", required = true },
  zig = { type = "binary", binary = "codelldb", mason_pkg = "codelldb", required = true },
  assembly = { type = "binary", binary = "gdb", required = true },
}

--- Language aliases for adapter reuse
---@type table<string, string>
M.language_aliases = {
  typescript = "javascript",
  typescriptreact = "javascript",
  javascriptreact = "javascript",
  cpp = "c",
  ["c++"] = "c",
  asm = "assembly",
  nasm = "assembly",
  gas = "assembly",
}

--- Default UI signs
---@type table<string, {text: string, texthl: string, linehl?: string, numhl?: string}>
M.signs = {
  DapBreakpoint = { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" },
  DapBreakpointCondition = { text = "◆", texthl = "DapBreakpointCondition", linehl = "", numhl = "" },
  DapBreakpointRejected = { text = "○", texthl = "DapBreakpointRejected", linehl = "", numhl = "" },
  DapLogPoint = { text = "◉", texthl = "DapLogPoint", linehl = "", numhl = "" },
  DapStopped = { text = "→", texthl = "DapStopped", linehl = "DapStoppedLine", numhl = "" },
}

--- Default highlight groups
---@type table<string, table>
M.highlights = {
  DapBreakpoint = { fg = "#e51400" },
  DapBreakpointCondition = { fg = "#ffcc00" },
  DapBreakpointRejected = { fg = "#888888" },
  DapLogPoint = { fg = "#61afef" },
  DapStopped = { fg = "#98c379" },
  DapStoppedLine = { bg = "#3e4451" },
}

--- Virtual text configuration (nvim-dap-virtual-text)
---@type table
M.virtual_text = {
  enabled = true,
  commented = true,
  virt_text_pos = "eol",
  all_frames = false,
  highlight_changed_variables = true,
  highlight_new_as_changed = true,
  show_stop_reason = true,
  only_first_definition = true,
  all_references = false,
}

--- DAP UI layout configuration (nvim-dap-ui)
---@type table
M.dapui_layout = {
  {
    elements = {
      { id = "scopes", size = 0.25 },
      { id = "breakpoints", size = 0.25 },
      { id = "stacks", size = 0.25 },
      { id = "watches", size = 0.25 },
    },
    size = 40,
    position = "left",
  },
  {
    elements = {
      { id = "repl", size = 0.5 },
      { id = "console", size = 0.5 },
    },
    size = 10,
    position = "bottom",
  },
}

--- Mason auto-install configuration
---@type string[]
M.mason_ensure_installed = {
  "js-debug-adapter",
  "codelldb",
  "delve",
  "debugpy",
}

--- Get adapter binary path with Mason fallback
---@param name string Adapter name
---@return string|nil path
function M.get_adapter_path(name)
  local adapter = M.adapter_binaries[name]
  if not adapter then
    return nil
  end

  -- Plugin-based adapters don't have binaries; return the plugin name so
  -- validate_adapter() can pcall(require, ...) it.
  if adapter.type == "plugin" then
    return adapter.binary
  end

  local exe = vim.fn.exepath(adapter.binary)
  if exe and exe ~= "" then
    return exe
  end

  if adapter.mason_pkg then
    local mason_path = vim.fn.stdpath("data") .. "/mason/bin/" .. adapter.binary
    if cross.is_windows() then
      mason_path = mason_path .. ".cmd"
    end
    local ok, stat = pcall(vim.uv.fs_stat, mason_path)
    if ok and stat then
      return mason_path
    end
  end

  return nil
end

--- Validate adapter availability
---@param name string Adapter name
---@return boolean available, string? error_message
function M.validate_adapter(name)
  local adapter = M.adapter_binaries[name]
  if not adapter then
    return false, string.format("Unknown adapter: %s", name)
  end

  if adapter.type == "plugin" then
    local ok = pcall(require, adapter.binary)
    if not ok then
      if adapter.required then
        return false, string.format("Required plugin '%s' not found", adapter.binary)
      end
      return false, string.format("Optional plugin '%s' not found", adapter.binary)
    end
    return true, nil
  end

  local path = M.get_adapter_path(name)
  if not path then
    if adapter.required then
      if adapter.mason_pkg then
        return false,
          string.format(
            "Required adapter '%s' not found. Install via Mason: %s",
            name,
            adapter.mason_pkg
          )
      end
      return false,
        string.format(
          "Required adapter '%s' not found: '%s' is not on PATH and has no Mason package. Install it manually (system package manager).",
          name,
          adapter.binary
        )
    end
    return false, string.format("Optional adapter '%s' not found", name)
  end

  return true, nil
end

return M
