--- Covers configurations.load_all()'s custom_configs merge: append by
--- default, replace when `replace = true` is set on the list. Uses a fake
--- `dap` module (just `{ configurations = {} }`) since only
--- `dap.configurations` is touched by this code path.
---
--- `languages` is deliberately a language that has no `wkddap.languages.*`
--- module, so the per-language load loop is a no-op and doesn't clobber the
--- `dap.configurations.python` entry seeded by each test before merging.

describe("wkddap.configurations custom_configs merge", function()
  before_each(function()
    package.loaded["dap"] = { configurations = {} }
    package.loaded["wkddap.configurations"] = nil
  end)

  after_each(function()
    package.loaded["dap"] = nil
  end)

  it("appends to existing configurations by default", function()
    local dap = package.loaded["dap"]
    dap.configurations.python = { { name = "existing" } }

    require("wkddap.configurations").load_all(
      { "not-a-real-language-xyz" },
      { python = { { name = "new" } } }
    )

    assert.are.equal(2, #dap.configurations.python)
    assert.are.equal("existing", dap.configurations.python[1].name)
    assert.are.equal("new", dap.configurations.python[2].name)
  end)

  it("replaces existing configurations when replace = true", function()
    local dap = package.loaded["dap"]
    dap.configurations.python = { { name = "existing" } }

    require("wkddap.configurations").load_all(
      { "not-a-real-language-xyz" },
      { python = { replace = true, { name = "new" } } }
    )

    assert.are.equal(1, #dap.configurations.python)
    assert.are.equal("new", dap.configurations.python[1].name)
  end)

  it("the replace marker itself never ends up in the stored list", function()
    local dap = package.loaded["dap"]

    require("wkddap.configurations").load_all(
      { "not-a-real-language-xyz" },
      { python = { replace = true, { name = "new" } } }
    )

    assert.is_nil(dap.configurations.python.replace)
  end)

  it("creates the language entry when it doesn't exist yet", function()
    local dap = package.loaded["dap"]

    require("wkddap.configurations").load_all(
      { "not-a-real-language-xyz" },
      { python = { { name = "new" } } }
    )

    assert.are.same({ { name = "new" } }, dap.configurations.python)
  end)

  it("custom_configs keys are used verbatim, not resolved through language_aliases", function()
    -- Unlike the per-language load loop above (which resolves "cs" ->
    -- "csharp" via wkddap.config.language_aliases before requiring a
    -- languages.* module), the custom_configs merge writes straight to
    -- dap.configurations[lang] with the key as given.
    local dap = package.loaded["dap"]

    require("wkddap.configurations").load_all(
      { "not-a-real-language-xyz" },
      { cs = { { name = "custom cs" } } }
    )

    assert.are.same({ { name = "custom cs" } }, dap.configurations.cs)
    assert.is_nil(dap.configurations.csharp)
  end)
end)

describe("wkddap.configurations.load_all() main load loop", function()
  before_each(function()
    _G.__configurations_warn_log = {}
    package.loaded["lib.nvim.notify"] = {
      create = function(_prefix)
        return {
          warn = function(msg)
            table.insert(_G.__configurations_warn_log, msg)
          end,
          info = function(_) end,
          error = function(_) end,
        }
      end,
    }
    package.loaded["wkddap.configurations"] = nil
  end)

  after_each(function()
    package.loaded["wkddap.configurations"] = nil
    package.loaded["lib.nvim.notify"] = nil
    package.loaded["wkddap.languages.python"] = nil
    package.loaded["dap"] = nil
    _G.__configurations_warn_log = nil
  end)

  it("always returns true, even when a language's load() raises", function()
    package.loaded["dap"] = { configurations = {} }
    package.loaded["wkddap.languages.python"] = {
      load = function()
        error("boom")
      end,
    }
    local configurations = require("wkddap.configurations")

    assert.is_true(configurations.load_all({ "python" }))
  end)

  it("notifies once, naming the language and the error, when load() raises", function()
    package.loaded["dap"] = { configurations = {} }
    package.loaded["wkddap.languages.python"] = {
      load = function()
        error("boom")
      end,
    }
    local configurations = require("wkddap.configurations")

    configurations.load_all({ "python" })

    assert.are.equal(1, #_G.__configurations_warn_log)
    assert.matches("python", _G.__configurations_warn_log[1])
    assert.matches("boom", _G.__configurations_warn_log[1])
  end)

  it("a language whose module can't be required at all is silently skipped (no warn)", function()
    package.loaded["dap"] = { configurations = {} }
    local configurations = require("wkddap.configurations")

    configurations.load_all({ "not-a-real-language-xyz" })

    assert.are.equal(0, #_G.__configurations_warn_log)
  end)
end)
