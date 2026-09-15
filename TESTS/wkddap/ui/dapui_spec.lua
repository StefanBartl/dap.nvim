--- Covers wkddap.ui.dapui.setup(): the dapui/dap presence gates, the
--- config.dapui_layout default (used only when the user gave no opts.dap_ui),
--- and that it wires the auto-open/close listeners on dap.listeners.

local dapui_mod = require("wkddap.ui.dapui")
local config = require("wkddap.config")

describe("wkddap.ui.dapui.setup()", function()
  after_each(function()
    package.loaded["dapui"] = nil
    package.loaded["dap"] = nil
  end)

  it("returns false when nvim-dap-ui isn't installed", function()
    package.loaded["dapui"] = nil
    package.loaded["dap"] = {}
    assert.is_false(dapui_mod.setup({}))
  end)

  it("returns false when dap isn't installed", function()
    package.loaded["dapui"] = { setup = function(_opts) end }
    package.loaded["dap"] = nil
    assert.is_false(dapui_mod.setup({}))
  end)

  it("defaults to config.dapui_layout when opts.dap_ui is absent", function()
    local received
    package.loaded["dapui"] = {
      setup = function(opts)
        received = opts
      end,
    }
    package.loaded["dap"] = {}

    assert.is_true(dapui_mod.setup({}))
    assert.are.same({ layouts = config.dapui_layout }, received)
  end)

  it("forwards opts.dap_ui verbatim instead of the default layout when given", function()
    local received
    package.loaded["dapui"] = {
      setup = function(opts)
        received = opts
      end,
    }
    package.loaded["dap"] = {}

    local custom = { layouts = {} }
    dapui_mod.setup({ dap_ui = custom })
    assert.are.equal(custom, received)
  end)

  it("wires open()/close() onto the session listeners", function()
    local opened, closed = false, false
    package.loaded["dapui"] = {
      setup = function(_opts) end,
      open = function()
        opened = true
      end,
      close = function()
        closed = true
      end,
    }
    package.loaded["dap"] = {}

    dapui_mod.setup({})
    local dap = package.loaded["dap"]

    dap.listeners.after.event_initialized["dapui_config"]()
    assert.is_true(opened)

    dap.listeners.before.event_terminated["dapui_config"]()
    assert.is_true(closed)
  end)
end)
