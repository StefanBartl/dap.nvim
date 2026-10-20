---@module 'wkddap.config'
--- Runtime configuration store, plus adapter/binary metadata for dap.nvim.
---
--- Merges user options over the immutable DEFAULTS and exposes the active
--- config via `get()`. Also carries the static per-language adapter/binary
--- table (Mason package names, UI signs/highlights/layout) consumed by the
--- registry, adapters, and UI modules.

local DEFAULTS = require("wkddap.config.DEFAULTS")
local executable = require("wkddap.utils.executable")

local M = {}

--- Stand-in for `languages` when the user's value has the wrong type. It
--- deliberately does NOT fall back to `DEFAULTS.languages` (`{}`): every
--- downstream consumer (`registry.register_all()`, `wkddap.adapters`,
--- `wkddap.configurations`, `wkddap.utils.mason`) treats an empty/absent
--- `languages` list as "every supported language", so reusing that default
--- here would silently turn a typo like `languages = "python"` into
--- "register every adapter and Mason-install every missing binary". This
--- name resolves to no known adapter (`registry.register()` fails with
--- "Unknown adapter"), so every consumer visibly registers/installs nothing
--- instead, same as a bad `languages` value did before validation existed.
---@type string[]
local INVALID_LANGUAGES = { "__invalid_languages_option__" }

--- What the schema inferred from `DEFAULTS` cannot say: `keymaps` carries
--- per-action overrides (`toggle_breakpoint = "<leader>xb"`, see
--- bindings/keymaps), and the two UI providers take an option table of their
--- own that has no default. `adapters` and `configurations` are keyed by adapter
--- resp. language name and empty in the defaults, so they are open already.
---@type table<string, string|table>
local SCHEMA = {
  keymaps = { "table" },
  ["ui.dap_view"] = "table",
  ["ui.dap_ui"] = "table",
}

local cfg = require("lib.lua.config").new(DEFAULTS, {
  name = "wkddap",
  schema = SCHEMA,
  -- Not the generic fallback to the default: `languages`' default (`{}`) means
  -- "enable everything" downstream, so falling back to it for a mistyped value
  -- would turn the mistake into silent over-provisioning instead of a safe no-op.
  normalize = function(opts, issues)
    if opts.languages ~= nil and type(opts.languages) ~= "table" then
      issues[#issues + 1] = string.format(
        "option 'languages' must be a table, got %s -- registering no languages (the default, an empty table, means \"all\" here, so it is not used as a fallback)",
        type(opts.languages)
      )
      opts.languages = INVALID_LANGUAGES
    end
  end,
  notify = function(message)
    require("wkddap.utils.notify").warn(message)
  end,
})

--- Set the options over the defaults and store the result. Every call starts
--- from `DEFAULTS`.
---
--- Unknown keys and mistyped option tables are reported once here and again
--- by `:checkhealth wkddap` (see `issues()`); they never reach the merge.
---@param user_opts? Dap.Config
---@return Dap.Config
function M.setup(user_opts)
  cfg.setup(type(user_opts) == "table" and user_opts or nil)
  return cfg.get()
end

--- The active config. A live reference to the stored table, not a copy: read
--- from it, never mutate it -- every other consumer (menu entries, health,
--- the UI wiring) sees the same table until the next `setup()`.
---@return Dap.Config
function M.get()
  return cfg.get()
end

--- What the last `setup()` ignored: unknown keys and option tables of the
--- wrong type, one human-readable line each. Empty when everything was
--- accepted.
---@return string[]
function M.issues()
  return cfg.issues()
end

--- Default adapter binaries and their Mason package names
---@type table<string, {binary?: string, mason_pkg?: string, required?: boolean, type: 'binary'|'plugin'}>
M.adapter_binaries = {
  lua = { type = "plugin", binary = "osv", required = false },
  javascript = {
    type = "binary",
    binary = "js-debug-adapter",
    mason_pkg = "js-debug-adapter",
    required = true,
  },
  go = { type = "binary", binary = "dlv", mason_pkg = "delve", required = true },
  -- `debugpy-adapter`, not `debugpy`: the Mason package ships both, and only
  -- the former starts the DAP adapter (`python -m debugpy.adapter`); the
  -- latter is the debugpy CLI, which insists on --listen/--connect.
  python = {
    type = "binary",
    binary = "debugpy-adapter",
    mason_pkg = "debugpy",
    required = true,
  },
  c = { type = "binary", binary = "codelldb", mason_pkg = "codelldb", required = true },
  rust = { type = "binary", binary = "codelldb", mason_pkg = "codelldb", required = true },
  zig = { type = "binary", binary = "codelldb", mason_pkg = "codelldb", required = true },
  assembly = { type = "binary", binary = "gdb", required = true },
  bash = {
    type = "binary",
    binary = "bash-debug-adapter",
    mason_pkg = "bash-debug-adapter",
    required = true,
  },
  csharp = {
    type = "binary",
    binary = "netcoredbg",
    mason_pkg = "netcoredbg",
    required = true,
  },
  -- Same package as `javascript`; separate entry so browser debugging can be
  -- enabled (and validated) on its own.
  browser = {
    type = "binary",
    binary = "js-debug-adapter",
    mason_pkg = "js-debug-adapter",
    required = true,
  },
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
  sh = "bash",
  zsh = "bash",
  ksh = "bash",
  cs = "csharp",
  fsharp = "csharp",
  dotnet = "csharp",
}

--- Default UI signs
---@type table<string, {text: string, texthl: string, linehl?: string, numhl?: string}>
M.signs = {
  DapBreakpoint = { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" },
  DapBreakpointCondition = {
    text = "◆",
    texthl = "DapBreakpointCondition",
    linehl = "",
    numhl = "",
  },
  DapBreakpointRejected = {
    text = "○",
    texthl = "DapBreakpointRejected",
    linehl = "",
    numhl = "",
  },
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

  -- Memoized, unlike the `vim.fn.exepath` this used to call directly. That
  -- matters here more than it looks: `codelldb` is the adapter for c, rust AND
  -- zig, so a plain exepath searched $PATH three separate times for the same
  -- binary. And a MISS is the expensive case -- it walks every $PATH entry and
  -- stats candidates before giving up, ~50-65ms each on Windows (every stat
  -- goes through the AV filter driver) versus a few ms when the binary is
  -- found and the walk stops early.
  --
  -- Measured on a machine with none of these installed: ~297ms for one lookup
  -- per binary, plus ~121ms for codelldb's two redundant repeats. That is what
  -- made this plugin's load time swing between 44ms and 328ms depending on how
  -- warm the OS cache was.
  local exe = executable.path(adapter.binary)
  if exe then
    return exe
  end

  -- Deliberately not memoized upstream: one fs_stat of a known path, no $PATH
  -- walk, and Mason installs binaries mid-session.
  if adapter.mason_pkg then
    local mason_path = executable.mason_path(adapter.binary)
    if mason_path then
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
