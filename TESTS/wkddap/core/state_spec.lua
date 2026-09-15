--- Covers wkddap.core.state's minimal session-state bookkeeping. Reloaded
--- per test since the module holds mutable, process-wide state with no
--- reset API of its own.

local function reload()
  package.loaded["wkddap.core.state"] = nil
  return require("wkddap.core.state")
end

describe("wkddap.core.state", function()
  it("starts uninitialized with no active session", function()
    local state = reload()
    assert.is_false(state.is_initialized())
    assert.is_false(state.is_session_active())
  end)

  it("init() marks the state initialized and returns true", function()
    local state = reload()
    assert.is_true(state.init())
    assert.is_true(state.is_initialized())
  end)

  it("set_session_active() toggles is_session_active() independently of init()", function()
    local state = reload()
    state.set_session_active(true)
    assert.is_true(state.is_session_active())
    assert.is_false(state.is_initialized(), "set_session_active() must not also mark init")

    state.set_session_active(false)
    assert.is_false(state.is_session_active())
  end)
end)
