--- Covers wkddap.ui.setup()'s orchestration: each sub-module's setup() is
--- pcall'd and only invoked when its own opts flag is on, so one broken/
--- absent module never blocks the others.

local function reload()
  package.loaded["wkddap.ui"] = nil
  return require("wkddap.ui")
end

describe("wkddap.ui.setup()", function()
  before_each(function()
    package.loaded["wkddap.ui.signs"] = nil
    package.loaded["wkddap.ui.highlights"] = nil
    package.loaded["wkddap.ui.provider"] = nil
    package.loaded["wkddap.ui.virtual_text"] = nil
  end)

  after_each(function()
    package.loaded["wkddap.ui.signs"] = nil
    package.loaded["wkddap.ui.highlights"] = nil
    package.loaded["wkddap.ui.provider"] = nil
    package.loaded["wkddap.ui.virtual_text"] = nil
  end)

  local function stub_all(called)
    package.loaded["wkddap.ui.signs"] = {
      setup = function()
        called.signs = true
      end,
    }
    package.loaded["wkddap.ui.highlights"] = {
      setup = function()
        called.highlights = true
      end,
    }
    package.loaded["wkddap.ui.provider"] = {
      setup = function(_opts)
        called.provider = true
      end,
    }
    package.loaded["wkddap.ui.virtual_text"] = {
      setup = function(opts)
        called.virtual_text = true
        called.virtual_text_opts = opts
      end,
    }
  end

  it("calls every sub-module when every flag is enabled", function()
    local called = {}
    stub_all(called)
    local ui = reload()

    ui.setup({ enable = true, signs = true, highlights = true, virtual_text = true })

    assert.is_true(called.signs)
    assert.is_true(called.highlights)
    assert.is_true(called.provider)
    assert.is_true(called.virtual_text)
  end)

  it("hands an opts.virtual_text table through to the virtual_text module", function()
    local called = {}
    stub_all(called)
    local ui = reload()

    local mine = { virt_text_pos = "inline" }
    ui.setup({ enable = false, signs = false, highlights = false, virtual_text = mine })

    assert.are.equal(mine, called.virtual_text_opts)
  end)

  it("skips each sub-module whose own flag is off", function()
    local called = {}
    stub_all(called)
    local ui = reload()

    ui.setup({ enable = false, signs = false, highlights = false, virtual_text = false })

    assert.is_nil(called.signs)
    assert.is_nil(called.highlights)
    assert.is_nil(called.provider)
    assert.is_nil(called.virtual_text)
  end)

  it("one sub-module erroring inside setup() does not block the others", function()
    local called = {}
    stub_all(called)
    package.loaded["wkddap.ui.signs"] = {
      setup = function()
        error("boom")
      end,
    }
    local ui = reload()

    assert.has_no.errors(function()
      ui.setup({ enable = true, signs = true, highlights = true, virtual_text = true })
    end)
    assert.is_true(called.highlights)
    assert.is_true(called.provider)
    assert.is_true(called.virtual_text)
  end)
end)
