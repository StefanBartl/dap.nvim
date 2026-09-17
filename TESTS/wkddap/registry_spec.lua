--- Covers registry.lua's pure bookkeeping paths: the fixed language list,
--- and register()/unregister() against a language that has no matching
--- adapter (so this never needs a real debug adapter binary on $PATH).

describe("wkddap.registry", function()
  local function reload()
    package.loaded["wkddap.registry"] = nil
    package.loaded["wkddap.config"] = nil
    return require("wkddap.registry")
  end

  it("available_languages() returns the fixed supported-language list", function()
    local registry = reload()
    local langs = registry.available_languages()

    table.sort(langs)
    assert.are.same({
      "assembly",
      "bash",
      "browser",
      "c",
      "cpp",
      "csharp",
      "go",
      "javascript",
      "lua",
      "python",
      "rust",
      "typescript",
      "zig",
    }, langs)
  end)

  it("available_languages() returns a defensive copy", function()
    local registry = reload()
    local langs = registry.available_languages()
    table.insert(langs, "not-a-real-language")

    assert.is_false(vim.tbl_contains(registry.available_languages(), "not-a-real-language"))
  end)

  it("register() fails for an unknown language without raising", function()
    local registry = reload()
    local ok, err = registry.register("not-a-real-language")

    assert.is_false(ok)
    assert.is_not_nil(err)
    assert.is_false(registry.is_registered("not-a-real-language"))
  end)

  it("is_enabled() is false for a language that was never registered", function()
    local registry = reload()
    assert.is_false(registry.is_enabled("python"))
  end)

  it("unregister() returns false for a language that isn't registered", function()
    local registry = reload()
    assert.is_false(registry.unregister("not-a-real-language"))
  end)

  it("stats() reports the available count from the fixed language list", function()
    local registry = reload()
    local stats = registry.stats()

    assert.are.equal(13, stats.available)
    assert.are.equal(0, stats.registered)
    assert.are.equal(0, stats.enabled)
  end)

  it("registered_languages()/enabled_languages() are both empty before any register()", function()
    local registry = reload()

    assert.are.same({}, registry.registered_languages())
    assert.are.same({}, registry.enabled_languages())
  end)
end)

--- register()/register_all()/validate() with a fully stubbed wkddap.config,
--- so the outcome doesn't depend on any real adapter being installed. Uses
--- its own reload helper: the plain `reload()` above always nils
--- wkddap.config too (forcing a fresh, real require), which would stomp a
--- stub set up beforehand.
local function reload_with_config(config_stub)
  package.loaded["wkddap.registry"] = nil
  package.loaded["wkddap.config"] = config_stub
  return require("wkddap.registry")
end

describe("wkddap.registry.register() with a stubbed adapter", function()
  after_each(function()
    package.loaded["wkddap.registry"] = nil
    package.loaded["wkddap.config"] = nil
    package.loaded["wkddap.languages.fakelang"] = nil
  end)

  it("succeeds, marks registered+enabled, and runs the adapter's setup()", function()
    local setup_called = false
    package.loaded["wkddap.languages.fakelang"] = {
      setup = function()
        setup_called = true
        return true
      end,
    }
    local registry = reload_with_config({
      language_aliases = {},
      validate_adapter = function(_)
        return true, nil
      end,
    })

    local ok, err = registry.register("fakelang")

    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_true(setup_called)
    assert.is_true(registry.is_registered("fakelang"))
    assert.is_true(registry.is_enabled("fakelang"))
  end)

  it(
    "registering the same language twice is a no-op the second time (setup() runs once)",
    function()
      local setup_calls = 0
      package.loaded["wkddap.languages.fakelang"] = {
        setup = function()
          setup_calls = setup_calls + 1
          return true
        end,
      }
      local registry = reload_with_config({
        language_aliases = {},
        validate_adapter = function(_)
          return true, nil
        end,
      })

      registry.register("fakelang")
      registry.register("fakelang")

      assert.are.equal(1, setup_calls)
    end
  )

  it("fails without registering when the adapter module's setup() errors", function()
    package.loaded["wkddap.languages.fakelang"] = {
      setup = function()
        error("adapter exploded")
      end,
    }
    local registry = reload_with_config({
      language_aliases = {},
      validate_adapter = function(_)
        return true, nil
      end,
    })

    local ok, err = registry.register("fakelang")

    assert.is_false(ok)
    assert.matches("adapter exploded", err)
    assert.is_false(registry.is_registered("fakelang"))
  end)

  it("unregister() reverses a successful register()", function()
    package.loaded["wkddap.languages.fakelang"] = {
      setup = function()
        return true
      end,
    }
    local registry = reload_with_config({
      language_aliases = {},
      validate_adapter = function(_)
        return true, nil
      end,
    })

    registry.register("fakelang")
    assert.is_true(registry.unregister("fakelang"))
    assert.is_false(registry.is_registered("fakelang"))
    assert.is_false(registry.is_enabled("fakelang"))
  end)

  it(
    "registered_languages() lists the requested name, enabled_languages() the alias-resolved one",
    function()
      package.loaded["wkddap.languages.realname"] = {
        setup = function()
          return true
        end,
      }
      local registry = reload_with_config({
        -- "fakelang" is requested but resolves (like typescript -> javascript)
        -- to a different adapter/module name; registered_languages() tracks
        -- the caller's own key, enabled_languages() the resolved one -- they
        -- are not the same list once an alias is involved.
        language_aliases = { fakelang = "realname" },
        validate_adapter = function(_)
          return true, nil
        end,
      })

      registry.register("fakelang")

      assert.are.same({ "fakelang" }, registry.registered_languages())
      assert.are.same({ "realname" }, registry.enabled_languages())
    end
  )
end)

describe("wkddap.registry.register_all()", function()
  after_each(function()
    package.loaded["wkddap.registry"] = nil
    package.loaded["wkddap.config"] = nil
    package.loaded["wkddap.languages.fakelang"] = nil
  end)

  it("returns a success map with one entry per requested language", function()
    package.loaded["wkddap.languages.fakelang"] = {
      setup = function()
        return true
      end,
    }
    local registry = reload_with_config({
      language_aliases = {},
      validate_adapter = function(name)
        return name == "fakelang", "unknown adapter: " .. name
      end,
    })

    local results = registry.register_all({ "fakelang", "not-a-real-language-xyz" })

    assert.is_true(results.fakelang)
    assert.is_false(results["not-a-real-language-xyz"])
  end)

  it("defaults to every SUPPORTED_LANGUAGES entry when given an empty list", function()
    local registry = reload_with_config({
      language_aliases = {},
      validate_adapter = function(_)
        return false, "no adapter"
      end,
    })

    local results = registry.register_all({})
    assert.are.equal(13, vim.tbl_count(results))
  end)
end)

describe("wkddap.registry.validate()", function()
  after_each(function()
    package.loaded["wkddap.registry"] = nil
    package.loaded["wkddap.config"] = nil
    package.loaded["wkddap.languages.fakelang"] = nil
  end)

  it("is valid with nothing enabled", function()
    local registry = reload_with_config({
      language_aliases = {},
      validate_adapter = function(_)
        return true, nil
      end,
    })

    local valid, errors = registry.validate()
    assert.is_true(valid)
    assert.are.same({}, errors)
  end)

  it("reports an enabled language whose adapter later stops validating", function()
    package.loaded["wkddap.languages.fakelang"] = {
      setup = function()
        return true
      end,
    }
    local still_valid = true
    local registry = reload_with_config({
      language_aliases = {},
      validate_adapter = function(_)
        if still_valid then
          return true, nil
        end
        return false, "binary vanished"
      end,
    })

    registry.register("fakelang")
    still_valid = false

    local valid, errors = registry.validate()
    assert.is_false(valid)
    assert.are.equal(1, #errors)
    assert.matches("binary vanished", errors[1])
  end)
end)
