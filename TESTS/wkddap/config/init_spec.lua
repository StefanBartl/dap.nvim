--- Covers wkddap.config: the setup()/get() singleton and deep-merge, and the
--- adapter-metadata helpers (get_adapter_path/validate_adapter).
---
--- get_adapter_path/validate_adapter walk the real filesystem (PATH lookup,
--- Mason install dir) for the *real* adapter_binaries table, whose outcome
--- depends on what happens to be installed on the machine running the suite.
--- Tests that need a deterministic "unresolvable" answer add a throwaway
--- entry to `config.adapter_binaries` with a binary name that cannot
--- plausibly exist, instead of asserting on any of the real language
--- entries, and remove it again afterwards.

local function reload()
  package.loaded["wkddap.config"] = nil
  return require("wkddap.config")
end

describe("wkddap.config: setup()/get() singleton", function()
  it("get() before any setup() returns a copy of DEFAULTS", function()
    local config = reload()
    local cfg = config.get()

    assert.are.same({}, cfg.languages)
    assert.is_true(cfg.ui.enable)
    assert.are.equal("dap-view", cfg.ui.provider)
  end)

  it("setup(nil) is equivalent to setup({}): defaults untouched", function()
    local config = reload()
    local cfg = config.setup(nil)

    assert.are.equal("dap-view", cfg.ui.provider)
    assert.are.equal(cfg, config.get(), "get() must return the same table setup() produced")
  end)

  it("setup() deep-merges user opts over defaults, preserving untouched nested fields", function()
    local config = reload()
    local cfg = config.setup({ ui = { provider = "dap-ui" } })

    assert.are.equal("dap-ui", cfg.ui.provider)
    -- Sibling default fields under `ui` survive an override of just one key.
    assert.is_true(cfg.ui.enable)
    assert.is_true(cfg.ui.signs)
  end)

  it("setup() never mutates the DEFAULTS module table", function()
    local config = reload()
    config.setup({ keymaps = { prefix = "<leader>x" } })

    local DEFAULTS = require("wkddap.config.DEFAULTS")
    assert.are.equal("<leader>d", DEFAULTS.keymaps.prefix)
  end)

  it("a non-table opts argument is treated as empty rather than erroring", function()
    local config = reload()
    assert.has_no.errors(function()
      config.setup("not-a-table")
    end)
  end)
end)

describe("wkddap.config.setup(): option validation", function()
  local orig_notify = vim.notify

  before_each(function()
    -- The issues are also announced through vim.notify; the test reads them
    -- from issues() and does not need the stderr noise.
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function() end
  end)

  after_each(function()
    vim.notify = orig_notify
  end)

  it("accepts every documented key without reporting an issue", function()
    local config = reload()
    config.setup({
      languages = { "python" },
      ui = { enable = true, provider = "auto", dap_view = {}, dap_ui = {} },
      keymaps = { enable = true, prefix = "<leader>x", toggle_breakpoint = "<leader>xb" },
      which_key = { enable = false },
      autocmds = { enable = false },
      menu = { enable = false },
      adapters = { codelldb = {} },
      configurations = { go = {} },
      auto_install = false,
      log_level = vim.log.levels.DEBUG,
    })

    assert.are.same({}, config.issues())
  end)

  it("drops an unknown top-level key and names the nearest known one", function()
    local config = reload()
    local cfg = config.setup({ keymap = { enable = false } })

    assert.is_nil(cfg.keymap)
    assert.is_true(cfg.keymaps.enable)
    assert.are.equal(1, #config.issues())
    assert.matches("'keymap'", config.issues()[1])
    assert.matches("did you mean 'keymaps'", config.issues()[1])
  end)

  it("drops an unknown nested key under an option table, keeping its siblings", function()
    local config = reload()
    local cfg = config.setup({ ui = { providers = "dap-ui", signs = false } })

    assert.are.equal("dap-view", cfg.ui.provider)
    assert.is_nil(cfg.ui.providers)
    assert.is_false(cfg.ui.signs)
    assert.matches("'ui.providers'", config.issues()[1])
    assert.matches("did you mean 'ui.provider'", config.issues()[1])
  end)

  it("a non-table value for an option table falls back to that table's defaults", function()
    local config = reload()
    local cfg = config.setup({ keymaps = false, autocmds = "off" })

    assert.is_true(cfg.keymaps.enable)
    assert.are.equal("<leader>d", cfg.keymaps.prefix)
    assert.is_true(cfg.autocmds.enable)
    assert.are.equal(2, #config.issues())
    assert.matches("'autocmds' must be a table, got string", config.issues()[1])
    assert.matches("'keymaps' must be a table, got boolean", config.issues()[2])
  end)

  it(
    "a non-table `adapters`/`configurations` falls back to {} instead of reaching register_all/load_all (ERR-22)",
    function()
      local config = reload()
      -- Before DEFAULTS carried explicit `adapters = {}` / `configurations = {}`
      -- entries, the generic "must be a table" guard above had nothing to
      -- compare against (`type(DEFAULTS.adapters) == "table"` was false
      -- because the key was simply absent) and let a wrong-typed value
      -- straight through to wkddap.adapters.register_all/
      -- wkddap.configurations.load_all, which both call `next()` on it and
      -- error -- a raw Lua error instead of a clean "using the default".
      local cfg = config.setup({ adapters = "codelldb", configurations = true })

      assert.are.same({}, cfg.adapters)
      assert.are.same({}, cfg.configurations)
      assert.are.equal(2, #config.issues())
      assert.matches("'adapters' must be a table, got string", config.issues()[1])
      assert.matches("'configurations' must be a table, got boolean", config.issues()[2])
    end
  )

  it(
    'a type-mismatched `languages` does not fall back to the default (which means "all")',
    function()
      local config = reload()
      -- `languages = "python"` is a plausible typo for `languages = { "python" }`.
      -- Falling back to DEFAULTS.languages (`{}`) here -- as the generic
      -- option-table rule does for keymaps/autocmds/etc. -- would be
      -- indistinguishable from the user asking for every language.
      local cfg = config.setup({ languages = "python" })

      assert.is_true(#cfg.languages > 0, "must not fall back to the empty ('all') default")
      -- None of the resulting entries name a real language: nothing gets
      -- registered or Mason-installed as a result.
      local available = {}
      for _, lang in ipairs(require("wkddap.registry").available_languages()) do
        available[lang] = true
      end
      for _, lang in ipairs(cfg.languages) do
        assert.is_nil(available[lang], "must not resolve to a real, registrable language")
      end

      assert.are.equal(1, #config.issues())
      assert.matches("'languages' must be a table, got string", config.issues()[1])
      assert.matches("registering no languages", config.issues()[1])
    end
  )

  it("a type-mismatched `languages` registers nothing instead of every adapter", function()
    local config = reload()
    config.setup({ languages = "python" })

    local registry = require("wkddap.registry")
    local results = registry.register_all(config.get().languages)

    for lang, ok in pairs(results) do
      assert.is_false(ok, lang .. " must not have registered")
    end
    assert.are.same({}, registry.enabled_languages())
  end)

  it("issues() reports only the most recent setup() and hands out a copy", function()
    local config = reload()
    config.setup({ nope = true })
    local first = config.issues()
    assert.are.equal(1, #first)

    table.insert(first, "mutated by the caller")
    assert.are.equal(1, #config.issues())

    config.setup({})
    assert.are.same({}, config.issues())
  end)
end)

describe("wkddap.config.get_adapter_path()", function()
  local config = require("wkddap.config")

  it("returns nil for a completely unknown adapter name", function()
    assert.is_nil(config.get_adapter_path("not-a-real-adapter-xyz"))
  end)

  it(
    "returns the plugin name directly for a plugin-type adapter (lua/osv), unconditionally",
    function()
      -- type = "plugin" short-circuits before any presence check -- see the
      -- comment in config/init.lua just above this branch.
      assert.are.equal("osv", config.get_adapter_path("lua"))
    end
  )

  it("returns nil for a binary-type adapter that cannot resolve on PATH or via Mason", function()
    config.adapter_binaries["__test_unresolvable__"] = {
      type = "binary",
      binary = "definitely-not-a-real-binary-xyz",
      required = true,
    }

    assert.is_nil(config.get_adapter_path("__test_unresolvable__"))

    config.adapter_binaries["__test_unresolvable__"] = nil
  end)
end)

describe("wkddap.config.validate_adapter()", function()
  local config = require("wkddap.config")

  it("reports an unknown adapter name", function()
    local ok, err = config.validate_adapter("not-a-real-adapter-xyz")
    assert.is_false(ok)
    assert.are.equal("Unknown adapter: not-a-real-adapter-xyz", err)
  end)

  it(
    "a required, unresolvable plugin-type adapter fails with a 'Required plugin' message",
    function()
      config.adapter_binaries["__test_plugin_required__"] =
        { type = "plugin", binary = "totally-fake-plugin-xyz", required = true }

      local ok, err = config.validate_adapter("__test_plugin_required__")
      assert.is_false(ok)
      assert.matches("Required plugin 'totally%-fake%-plugin%-xyz' not found", err)

      config.adapter_binaries["__test_plugin_required__"] = nil
    end
  )

  it(
    "an optional, unresolvable plugin-type adapter fails with an 'Optional plugin' message",
    function()
      config.adapter_binaries["__test_plugin_optional__"] =
        { type = "plugin", binary = "totally-fake-plugin-xyz", required = false }

      local ok, err = config.validate_adapter("__test_plugin_optional__")
      assert.is_false(ok)
      assert.matches("Optional plugin 'totally%-fake%-plugin%-xyz' not found", err)

      config.adapter_binaries["__test_plugin_optional__"] = nil
    end
  )

  it(
    "a required binary-type adapter with no mason_pkg reports the manual-install message",
    function()
      config.adapter_binaries["__test_binary_no_mason__"] =
        { type = "binary", binary = "definitely-not-a-real-binary-xyz", required = true }

      local ok, err = config.validate_adapter("__test_binary_no_mason__")
      assert.is_false(ok)
      assert.matches("not on PATH and has no Mason package", err)

      config.adapter_binaries["__test_binary_no_mason__"] = nil
    end
  )

  it("a required binary-type adapter with a mason_pkg points at Mason instead", function()
    config.adapter_binaries["__test_binary_with_mason__"] = {
      type = "binary",
      binary = "definitely-not-a-real-binary-xyz",
      mason_pkg = "fake-mason-pkg",
      required = true,
    }

    local ok, err = config.validate_adapter("__test_binary_with_mason__")
    assert.is_false(ok)
    assert.matches("Install via Mason: fake%-mason%-pkg", err)

    config.adapter_binaries["__test_binary_with_mason__"] = nil
  end)

  it(
    "an optional, unresolvable binary-type adapter fails with an 'Optional adapter' message",
    function()
      config.adapter_binaries["__test_binary_optional__"] =
        { type = "binary", binary = "definitely-not-a-real-binary-xyz", required = false }

      local ok, err = config.validate_adapter("__test_binary_optional__")
      assert.is_false(ok)
      assert.matches("Optional adapter '__test_binary_optional__' not found", err)

      config.adapter_binaries["__test_binary_optional__"] = nil
    end
  )
end)

describe("wkddap.config.language_aliases", function()
  local config = require("wkddap.config")

  it("maps every documented alias to its canonical adapter name", function()
    assert.are.equal("javascript", config.language_aliases.typescript)
    assert.are.equal("c", config.language_aliases.cpp)
    assert.are.equal("assembly", config.language_aliases.asm)
    assert.are.equal("bash", config.language_aliases.sh)
    assert.are.equal("csharp", config.language_aliases.cs)
  end)
end)
