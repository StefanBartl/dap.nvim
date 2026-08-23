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

    assert.are.equal(10, stats.available)
    assert.are.equal(0, stats.registered)
    assert.are.equal(0, stats.enabled)
  end)
end)
