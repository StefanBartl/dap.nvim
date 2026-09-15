--- Covers wkddap.core.breakpoints' prompt pre-fill/reuse logic: the value
--- shown by default is the breakpoint already on the current line, else the
--- last value submitted this session, else empty -- and an empty submit is
--- still applied (clears the condition) rather than treated as a cancel.
---
--- `require("dap.breakpoints").get(bufnr)` is pcall'd by the module under
--- test itself and fails in this environment (no real nvim-dap), so every
--- case here exercises the "no existing breakpoint at this line" path; the
--- "prefilled from an existing breakpoint" branch would need a real
--- `dap.breakpoints` module and is out of scope per TESTS/README.md.

local breakpoints = require("wkddap.core.breakpoints")

describe("wkddap.core.breakpoints", function()
  before_each(function()
    breakpoints.forget()
    _G.__set_breakpoint_calls = {}
    package.loaded["dap"] = {
      -- `{ n = select("#", ...), ... }` (not a bare `{ ... }` literal, and
      -- not table.pack -- unavailable under LuaJIT) so a call passing `nil`
      -- in a leading position -- prompt_log_point's `set_breakpoint(nil,
      -- nil, message)` -- still records its true argument count instead of
      -- silently truncating at the first hole.
      set_breakpoint = function(...)
        table.insert(_G.__set_breakpoint_calls, { n = select("#", ...), ... })
      end,
    }
    package.loaded["ui.kit"] = {
      input = function(opts)
        _G.__captured_input_opts = opts
      end,
    }
  end)

  after_each(function()
    breakpoints.forget()
    package.loaded["dap"] = nil
    package.loaded["ui.kit"] = nil
    _G.__set_breakpoint_calls = nil
    _G.__captured_input_opts = nil
  end)

  it("prompt_condition() defaults to empty with no prior state", function()
    breakpoints.prompt_condition()
    assert.are.equal("Breakpoint condition: ", _G.__captured_input_opts.title)
    assert.are.equal("", _G.__captured_input_opts.default)
  end)

  it("prompt_condition() submit calls dap.set_breakpoint(condition)", function()
    breakpoints.prompt_condition()
    _G.__captured_input_opts.on_submit("x == 1")

    assert.are.equal(1, #_G.__set_breakpoint_calls)
    local call = _G.__set_breakpoint_calls[1]
    assert.are.equal(1, call.n)
    assert.are.equal("x == 1", call[1])
  end)

  it("reuses the last submitted, non-empty condition as the next prompt's default", function()
    breakpoints.prompt_condition()
    _G.__captured_input_opts.on_submit("x == 1")

    breakpoints.prompt_condition()
    assert.are.equal("x == 1", _G.__captured_input_opts.default)
  end)

  it("submitting an empty condition does not overwrite the remembered last value", function()
    breakpoints.prompt_condition()
    _G.__captured_input_opts.on_submit("x == 1")

    breakpoints.prompt_condition()
    _G.__captured_input_opts.on_submit("")

    breakpoints.prompt_condition()
    assert.are.equal("x == 1", _G.__captured_input_opts.default)
  end)

  it("on_submit(nil) is treated as an empty value, not an error", function()
    breakpoints.prompt_condition()
    assert.has_no.errors(function()
      _G.__captured_input_opts.on_submit(nil)
    end)
    assert.are.equal("", _G.__set_breakpoint_calls[1][1])
  end)

  it("forget() clears the remembered condition back to empty", function()
    breakpoints.prompt_condition()
    _G.__captured_input_opts.on_submit("x == 1")
    breakpoints.forget()

    breakpoints.prompt_condition()
    assert.are.equal("", _G.__captured_input_opts.default)
  end)

  it("prompt_log_point() defaults to empty and calls set_breakpoint(nil, nil, message)", function()
    breakpoints.prompt_log_point()
    assert.are.equal("Log message: ", _G.__captured_input_opts.title)
    assert.are.equal("", _G.__captured_input_opts.default)

    _G.__captured_input_opts.on_submit("hit here")
    local call = _G.__set_breakpoint_calls[1]
    assert.are.equal(3, call.n)
    assert.is_nil(call[1])
    assert.is_nil(call[2])
    assert.are.equal("hit here", call[3])
  end)

  it("condition and log-point history are tracked independently", function()
    breakpoints.prompt_condition()
    _G.__captured_input_opts.on_submit("x == 1")

    breakpoints.prompt_log_point()
    assert.are.equal("", _G.__captured_input_opts.default, "log point history starts empty")

    _G.__captured_input_opts.on_submit("hit here")

    breakpoints.prompt_condition()
    assert.are.equal(
      "x == 1",
      _G.__captured_input_opts.default,
      "condition history untouched by log point"
    )
  end)
end)
