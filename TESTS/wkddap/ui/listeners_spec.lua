--- Covers wkddap.ui.listeners: the shared creation of dap.listeners tables and the open/close wiring the
--- two panel UI providers (dap-ui, dap-view) and the memory view use.

local listeners = require("wkddap.ui.listeners")

describe("wkddap.ui.listeners.set()", function()
  it("creates every missing table, even on a bare double", function()
    local dap = {}
    local fn = function() end
    listeners.set(dap, "after", "event_initialized", "k", fn)
    assert.are.equal(fn, dap.listeners.after.event_initialized.k)
    assert.is_table(dap.listeners.before)
  end)

  it("keeps what is already registered under other keys and replaces the same key", function()
    local other = function() end
    local dap = { listeners = { before = {}, after = { event_exited = { other = other } } } }
    local first, second = function() end, function() end
    listeners.set(dap, "after", "event_exited", "k", first)
    listeners.set(dap, "after", "event_exited", "k", second)
    assert.are.equal(other, dap.listeners.after.event_exited.other)
    assert.are.equal(second, dap.listeners.after.event_exited.k)
  end)
end)

describe("wkddap.ui.listeners.open_close()", function()
  it("opens after initialized and closes before terminated and before exited", function()
    local dap = {}
    local open, close = function() end, function() end
    listeners.open_close(dap, "key", open, close)
    assert.are.equal(open, dap.listeners.after.event_initialized.key)
    assert.are.equal(close, dap.listeners.before.event_terminated.key)
    assert.are.equal(close, dap.listeners.before.event_exited.key)
  end)
end)
