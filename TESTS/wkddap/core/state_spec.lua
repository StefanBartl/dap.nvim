--- Covers wkddap.core.state's "core setup has run" marker. Reloaded per test
--- since the module holds mutable, process-wide state with no reset API of
--- its own.

local function reload()
  package.loaded["wkddap.core.state"] = nil
  return require("wkddap.core.state")
end

describe("wkddap.core.state", function()
  it("starts uninitialized", function()
    local state = reload()
    assert.is_false(state._state.initialized)
  end)

  it("init() marks the state initialized and returns true", function()
    local state = reload()
    assert.is_true(state.init())
    assert.is_true(state._state.initialized)
  end)
end)
