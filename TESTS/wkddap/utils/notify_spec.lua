--- Covers wkddap.utils.notify: a thin, prefixed wrapper over
--- lib.nvim.notify.create() (unlike wkddap.utils.executable, this is not a
--- pure re-export -- M.info/warn/error each close over the notifier that
--- create() returns and forward one argument to it). lib.nvim.notify is
--- stubbed via package.loaded so this only asserts the wrapping itself:
--- which prefix create() is called with, and that each of the three methods
--- forwards to the matching method on the created notifier.

local function reload()
  package.loaded["wkddap.utils.notify"] = nil
  return require("wkddap.utils.notify")
end

describe("wkddap.utils.notify", function()
  local original_notify_module
  local captured_prefix
  local captured_calls

  before_each(function()
    captured_prefix = nil
    captured_calls = {}
    original_notify_module = package.loaded["lib.nvim.notify"]
    package.loaded["lib.nvim.notify"] = {
      create = function(prefix)
        captured_prefix = prefix
        return {
          info = function(msg)
            table.insert(captured_calls, { "info", msg })
          end,
          warn = function(msg)
            table.insert(captured_calls, { "warn", msg })
          end,
          error = function(msg)
            table.insert(captured_calls, { "error", msg })
          end,
        }
      end,
    }
  end)

  after_each(function()
    package.loaded["lib.nvim.notify"] = original_notify_module
    package.loaded["wkddap.utils.notify"] = nil
  end)

  it("creates its notifier with the '[dap.nvim]' prefix", function()
    reload()
    assert.are.equal("[dap.nvim]", captured_prefix)
  end)

  it("M.info() forwards the message to the notifier's info()", function()
    local notify = reload()
    notify.info("hello")
    assert.are.same({ { "info", "hello" } }, captured_calls)
  end)

  it("M.warn() forwards the message to the notifier's warn()", function()
    local notify = reload()
    notify.warn("careful")
    assert.are.same({ { "warn", "careful" } }, captured_calls)
  end)

  it("M.error() forwards the message to the notifier's error()", function()
    local notify = reload()
    notify.error("broken")
    assert.are.same({ { "error", "broken" } }, captured_calls)
  end)
end)
