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
