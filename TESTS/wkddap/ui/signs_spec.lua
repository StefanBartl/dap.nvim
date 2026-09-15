--- Covers wkddap.ui.signs.setup(): applies config.signs via real
--- vim.fn.sign_define() calls -- a built-in Neovim API, not part of
--- nvim-dap-ui/dap-view, so this needs no panel-UI plugin installed.

local signs = require("wkddap.ui.signs")
local config = require("wkddap.config")

describe("wkddap.ui.signs.setup()", function()
  it("defines every configured sign via sign_define", function()
    signs.setup()

    for name, sign in pairs(config.signs) do
      local defined = vim.fn.sign_getdefined(name)
      assert.are.equal(1, #defined, ("sign %s should be defined"):format(name))
      -- sign_getdefined() pads single-cell glyphs to 2 print cells with a
      -- trailing space; compare the configured glyph as a prefix rather than
      -- the padded string verbatim.
      assert.are.equal(sign.text, defined[1].text:sub(1, #sign.text))
    end
  end)
end)
