--- Covers wkddap.ui.dapview.setup(): the dap-view/dap presence gates, and
--- that it wires the auto-open/close listeners on dap.listeners.

local dapview = require("wkddap.ui.dapview")

describe("wkddap.ui.dapview.setup()", function()
  after_each(function()
    package.loaded["dap-view"] = nil
    package.loaded["dap"] = nil
  end)

  it("returns false when dap-view isn't installed", function()
    package.loaded["dap-view"] = nil
    package.loaded["dap"] = {}
    assert.is_false(dapview.setup({}))
  end)

  it("returns false when dap isn't installed", function()
    package.loaded["dap-view"] = { setup = function(_opts) end }
    package.loaded["dap"] = nil
    assert.is_false(dapview.setup({}))
  end)

  it("returns false when dap-view's own setup() errors", function()
    package.loaded["dap-view"] = {
      setup = function(_opts)
        error("bad opts")
      end,
    }
    package.loaded["dap"] = {}
    assert.is_false(dapview.setup({ dap_view = {} }))
  end)

  it("forwards opts.dap_view to dap-view.setup() and wires the session listeners", function()
    local received_opts
    package.loaded["dap-view"] = {
      setup = function(opts)
        received_opts = opts
      end,
    }
    package.loaded["dap"] = {}

    local dap_view_opts = { winbar = false }
    assert.is_true(dapview.setup({ dap_view = dap_view_opts }))
    assert.are.equal(dap_view_opts, received_opts)

    local dap = package.loaded["dap"]
    assert.are.equal("function", type(dap.listeners.after.event_initialized["dap_dapview"]))
    assert.are.equal("function", type(dap.listeners.before.event_terminated["dap_dapview"]))
    assert.are.equal("function", type(dap.listeners.before.event_exited["dap_dapview"]))
  end)

  it("the open/close listeners pcall into dap-view (survive it lacking open/close)", function()
    package.loaded["dap-view"] = { setup = function(_opts) end }
    package.loaded["dap"] = {}
    dapview.setup({})

    local dap = package.loaded["dap"]
    assert.has_no.errors(function()
      dap.listeners.after.event_initialized["dap_dapview"]()
      dap.listeners.before.event_terminated["dap_dapview"]()
    end)
  end)
end)
