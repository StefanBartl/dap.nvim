--- Covers wkddap.ui.virtual_text.setup(): a soft dependency on
--- nvim-dap-virtual-text, wired with config.virtual_text when present and a
--- silent no-op otherwise.

local virtual_text = require("wkddap.ui.virtual_text")
local config = require("wkddap.config")

describe("wkddap.ui.virtual_text.setup()", function()
  after_each(function()
    package.loaded["nvim-dap-virtual-text"] = nil
  end)

  it("is a silent no-op when nvim-dap-virtual-text isn't installed", function()
    package.loaded["nvim-dap-virtual-text"] = nil
    assert.has_no.errors(function()
      virtual_text.setup()
    end)
  end)

  it("forwards config.virtual_text to nvim-dap-virtual-text's setup() when installed", function()
    local received
    package.loaded["nvim-dap-virtual-text"] = {
      setup = function(opts)
        received = opts
      end,
    }

    virtual_text.setup()
    assert.are.equal(config.virtual_text, received)
  end)

  it("uses config.virtual_text for `true` too (the plain on-switch)", function()
    local received
    package.loaded["nvim-dap-virtual-text"] = {
      setup = function(opts)
        received = opts
      end,
    }

    virtual_text.setup(true)
    assert.are.equal(config.virtual_text, received)
  end)

  it("hands a user table to nvim-dap-virtual-text's setup() as given, not merged", function()
    -- Mirrors ui.dap_view / ui.dap_ui: the user's table is their whole
    -- configuration, dap.nvim does not fight the plugin's schema by
    -- merging its own defaults underneath.
    local received
    package.loaded["nvim-dap-virtual-text"] = {
      setup = function(opts)
        received = opts
      end,
    }

    local mine = { virt_text_pos = "inline" }
    virtual_text.setup(mine)
    assert.are.equal(mine, received)
  end)
end)
