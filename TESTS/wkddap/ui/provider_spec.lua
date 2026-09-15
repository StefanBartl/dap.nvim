--- Covers wkddap.ui.provider: preference resolution ('none'/'auto'/a
--- concrete provider, with fallback to the other one), and toggle()/eval()
--- dispatch to whichever provider ended up active -- all via a stubbed
--- 'dap-view' + 'dap' (real absence of both is also exercised, for the
--- "nothing available" paths).

local function reload()
  package.loaded["wkddap.ui.provider"] = nil
  return require("wkddap.ui.provider")
end

describe("wkddap.ui.provider.setup(): preference resolution", function()
  after_each(function()
    package.loaded["dap-view"] = nil
    package.loaded["dapui"] = nil
    package.loaded["dap"] = nil
  end)

  it("provider = 'none' wires nothing", function()
    local provider = reload()
    assert.is_nil(provider.setup({ provider = "none" }))
    assert.is_nil(provider.active())
  end)

  it("a concrete preference with neither plugin installed resolves to nil", function()
    local provider = reload()
    assert.is_nil(provider.setup({ provider = "dap-view" }))
    assert.is_nil(provider.active())
  end)

  it("'auto' with neither plugin installed resolves to nil", function()
    local provider = reload()
    assert.is_nil(provider.setup({ provider = "auto" }))
  end)

  it("wires dap-view when it's installed and dap is present", function()
    package.loaded["dap-view"] = { setup = function(_opts) end }
    package.loaded["dap"] = {}
    local provider = reload()

    assert.are.equal("dap-view", provider.setup({ provider = "dap-view" }))
    assert.are.equal("dap-view", provider.active())
  end)

  it("falls back to dap-view when the preferred dap-ui isn't installed", function()
    package.loaded["dap-view"] = { setup = function(_opts) end }
    package.loaded["dap"] = {}
    local provider = reload()

    assert.are.equal("dap-view", provider.setup({ provider = "dap-ui" }))
  end)

  it("'auto' picks dap-view when it's the only one installed", function()
    package.loaded["dap-view"] = { setup = function(_opts) end }
    package.loaded["dap"] = {}
    local provider = reload()

    assert.are.equal("dap-view", provider.setup({ provider = "auto" }))
  end)

  it("returns nil and clears active() when the resolved provider's own setup() fails", function()
    package.loaded["dap-view"] = { setup = function(_opts) end }
    package.loaded["dap"] = nil -- wkddap.ui.dapview.setup() requires dap too; absent -> its setup() returns false
    local provider = reload()

    assert.is_nil(provider.setup({ provider = "dap-view" }))
    assert.is_nil(provider.active())
  end)
end)

describe("wkddap.ui.provider: toggle()/eval() dispatch", function()
  after_each(function()
    package.loaded["dap-view"] = nil
    package.loaded["dap"] = nil
  end)

  it("toggle() calls the active dap-view module's toggle()", function()
    local toggled = false
    package.loaded["dap-view"] = {
      setup = function(_opts) end,
      toggle = function()
        toggled = true
      end,
    }
    package.loaded["dap"] = {}
    local provider = reload()
    provider.setup({ provider = "dap-view" })

    provider.toggle()
    assert.is_true(toggled)
  end)

  it("toggle() falls back to :DapViewToggle when the module has no toggle()", function()
    package.loaded["dap-view"] = { setup = function(_opts) end }
    package.loaded["dap"] = {}
    local provider = reload()
    provider.setup({ provider = "dap-view" })

    local orig_cmd = vim.cmd
    local seen
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.cmd = function(cmd)
      seen = cmd
    end
    provider.toggle()
    vim.cmd = orig_cmd

    assert.are.equal("DapViewToggle", seen)
  end)

  it("eval() calls add_expr() when present on the dap-view module", function()
    local called = false
    package.loaded["dap-view"] = {
      setup = function(_opts) end,
      add_expr = function()
        called = true
      end,
    }
    package.loaded["dap"] = {}
    local provider = reload()
    provider.setup({ provider = "dap-view" })

    provider.eval()
    assert.is_true(called)
  end)

  it("toggle()/eval() are silent no-ops (no error) when no provider is active", function()
    local provider = reload()
    assert.has_no.errors(function()
      provider.toggle()
      provider.eval()
    end)
  end)
end)
