--- Covers wkddap.ui.highlights.setup(): applies config.highlights via real
--- vim.api.nvim_set_hl() calls -- a built-in Neovim API, so this needs no
--- panel-UI plugin installed.

local highlights = require("wkddap.ui.highlights")
local config = require("wkddap.config")

describe("wkddap.ui.highlights.setup()", function()
  it("applies every configured highlight group via nvim_set_hl", function()
    highlights.setup()

    for name, hl in pairs(config.highlights) do
      local applied = vim.api.nvim_get_hl(0, { name = name })
      if hl.fg then
        assert.is_not_nil(applied.fg, ("%s should have fg set"):format(name))
      end
      if hl.bg then
        assert.is_not_nil(applied.bg, ("%s should have bg set"):format(name))
      end
    end
  end)
end)
