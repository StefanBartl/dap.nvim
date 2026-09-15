--- Covers wkddap.utils.validation.pick_process(), the process picker behind
--- the JS/TS "Attach" config's `processId`.
---
--- nvim-dap calls `processId` from inside its own coroutine.wrap()'d config
--- resolution and expects a thread back when async resolution is needed (the
--- same contract the language `program()` prompts use, per
--- languages/program_prompt_spec.lua) -- so pick_process() only does
--- anything once called from inside a coroutine, and its real work happens
--- on the *returned* coroutine, not before returning.

local validation = require("wkddap.utils.validation")

describe("wkddap.utils.validation.pick_process()", function()
  -- The "called outside a coroutine -> nil" guard isn't exercisable from an
  -- `it()` block: plenary's busted-style runner itself executes every test
  -- inside a coroutine, so `coroutine.running()` is never nil there. It's
  -- covered structurally instead, by every other case below always calling
  -- pick_process() from inside an explicit, separate coroutine and getting a
  -- thread back rather than nil.

  it("returns a not-yet-started coroutine when called from inside one", function()
    local inner
    local outer = coroutine.create(function()
      inner = validation.pick_process()
    end)
    coroutine.resume(outer)

    assert.are.equal("thread", type(inner))
    assert.are.equal("suspended", coroutine.status(inner))
  end)

  describe("the returned coroutine's picker flow", function()
    before_each(function()
      package.loaded["ui.kit"] = {
        select = function(opts)
          _G.__captured_select_opts = opts
        end,
      }
    end)

    after_each(function()
      package.loaded["ui.kit"] = nil
      _G.__captured_select_opts = nil
    end)

    --- Mirrors how nvim-dap actually drives a `processId` field that returns
    --- a thread: call pick_process() from inside the resolving coroutine,
    --- resume the inner picker thread it hands back to kick off the async
    --- work, then yield the *resolving* coroutine itself -- pick_process()
    --- resumes that same coroutine (the `co` it captured via
    --- coroutine.running()) with the final pid once the picker's on_select/
    --- on_cancel fires. vim.wait pumps the event loop so the vim.schedule'd
    --- open_picker() actually runs before this returns.
    ---@return thread outer
    ---@return fun(): any get_result
    local function start()
      local result
      local outer = coroutine.create(function()
        local inner = validation.pick_process()
        coroutine.resume(inner)
        result = coroutine.yield()
      end)
      coroutine.resume(outer)
      vim.wait(500, function()
        return _G.__captured_select_opts ~= nil
      end, 1)
      return outer, function()
        return result
      end
    end

    it("parses ps output into items and resolves the selected pid", function()
      local orig_system = vim.system
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.system = function(_argv, _opts, on_exit)
        on_exit({ code = 0, stdout = "  123 nvim\n  456 zsh\n", stderr = "" })
      end

      local outer, get_result = start()
      vim.system = orig_system

      assert.is_not_nil(_G.__captured_select_opts, "ui.kit.select was called")
      assert.are.same({ "  123 nvim", "  456 zsh" }, _G.__captured_select_opts.items)

      _G.__captured_select_opts.on_select("  123 nvim")
      assert.are.equal("dead", coroutine.status(outer))
      assert.are.equal(123, get_result())
    end)

    it("resolves to nil when the picker is cancelled", function()
      local orig_system = vim.system
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.system = function(_argv, _opts, on_exit)
        on_exit({ code = 0, stdout = "123 nvim\n", stderr = "" })
      end

      local outer, get_result = start()
      vim.system = orig_system

      _G.__captured_select_opts.on_cancel()
      assert.are.equal("dead", coroutine.status(outer))
      assert.is_nil(get_result())
    end)

    it("opens the picker with an empty list when the process listing fails", function()
      local orig_system = vim.system
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.system = function(_argv, _opts, on_exit)
        on_exit({ code = 1, stdout = "", stderr = "ps: not found" })
      end

      start()
      vim.system = orig_system

      assert.are.same({}, _G.__captured_select_opts.items)
    end)
  end)
end)
