--- Covers wkddap.adapters.register_all(): delegates each language to
--- wkddap.registry.register(), defaults to every available language when
--- none are given, and always returns true regardless of failures (the
--- per-language reason is only surfaced via the summary notify.warn / later
--- :checkhealth, not the return value).

local function reload()
  package.loaded["wkddap.adapters"] = nil
  return require("wkddap.adapters")
end

describe("wkddap.adapters.register_all()", function()
  after_each(function()
    package.loaded["wkddap.registry"] = nil
  end)

  it("calls registry.register() once per requested language", function()
    local calls = {}
    package.loaded["wkddap.registry"] = {
      register = function(lang)
        table.insert(calls, lang)
        return true
      end,
    }
    local adapters = reload()

    assert.is_true(adapters.register_all({ "python", "go" }))
    assert.are.same({ "python", "go" }, calls)
  end)

  it("defaults to registry.available_languages() when given an empty/nil list", function()
    local calls = {}
    package.loaded["wkddap.registry"] = {
      available_languages = function()
        return { "lua", "rust" }
      end,
      register = function(lang)
        table.insert(calls, lang)
        return true
      end,
    }
    local adapters = reload()

    adapters.register_all({})
    assert.are.same({ "lua", "rust" }, calls)

    calls = {}
    adapters.register_all(nil)
    assert.are.same({ "lua", "rust" }, calls)
  end)

  it("returns true even when every language fails to register", function()
    package.loaded["wkddap.registry"] = {
      register = function(_)
        return false
      end,
    }
    local adapters = reload()

    assert.is_true(adapters.register_all({ "python", "go" }))
  end)
end)
