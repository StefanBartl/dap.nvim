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
end)
