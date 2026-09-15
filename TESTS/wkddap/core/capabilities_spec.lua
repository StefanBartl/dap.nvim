--- Covers wkddap.core.capabilities.detect()/has(): a pure pcall(require, ...)
--- probe over four optional companion plugins, none of which are installed
--- in this environment -- except where stubbed via package.loaded, which is
--- indistinguishable from a real install as far as `pcall(require, ...)` is
--- concerned.

local function reload()
  package.loaded["wkddap.core.capabilities"] = nil
  return require("wkddap.core.capabilities")
end

describe("wkddap.core.capabilities", function()
  after_each(function()
    package.loaded["dapui"] = nil
    package.loaded["dap-view"] = nil
    package.loaded["nvim-dap-virtual-text"] = nil
  end)

  it("detect() reports every companion plugin absent by default", function()
    local capabilities = reload()
    local features = capabilities.detect()

    assert.is_false(features.dap)
    assert.is_false(features.dapui)
    assert.is_false(features.dapview)
    assert.is_false(features.virtual_text)
  end)

  it("has() mirrors the last detect() result", function()
    local capabilities = reload()
    capabilities.detect()

    assert.is_false(capabilities.has("dapui"))
    assert.is_false(capabilities.has("nonexistent-feature"))
  end)

  it("has() reflects a stubbed-present companion after detect() re-runs", function()
    local capabilities = reload()
    package.loaded["dapui"] = {}

    capabilities.detect()
    assert.is_true(capabilities.has("dapui"))
  end)

  it("has() before any detect() call reports everything absent", function()
    local capabilities = reload()
    assert.is_false(capabilities.has("dap"))
  end)
end)
