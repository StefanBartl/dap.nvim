--- Covers bindings.usercmds.setup(): all 14 :Dap routes register and show
--- up in completion. setup() only closes over require("dap")/
--- require("wkddap.ui.provider") inside route `run` callbacks, so this
--- never needs nvim-dap or the UI providers installed.

describe("wkddap.bindings.usercmds", function()
  local EXPECTED_SUBCOMMANDS = {
    "continue",
    "step-over",
    "step-into",
    "step-out",
    "terminate",
    "restart",
    "toggle-breakpoint",
    "conditional-breakpoint",
    "log-point",
    "list-breakpoints",
    "toggle-ui",
    "eval",
    "repl",
    "memory",
    "memory-window",
  }

  local function reload()
    package.loaded["wkddap.bindings.usercmds"] = nil
    return require("wkddap.bindings.usercmds")
  end

  it("registers the :Dap user command", function()
    reload().setup()
    assert.is_not_nil(vim.api.nvim_get_commands({})["Dap"])
  end)

  it("completes every expected subcommand", function()
    reload().setup()
    local completions = vim.fn.getcompletion("Dap ", "cmdline")

    for _, sub in ipairs(EXPECTED_SUBCOMMANDS) do
      assert.is_true(
        vim.tbl_contains(completions, sub),
        string.format(
          "expected :Dap completion to contain %q, got: %s",
          sub,
          vim.inspect(completions)
        )
      )
    end
  end)

  it(":Dap memory hands its argument (or nothing) to wkddap.memory.open()", function()
    reload().setup()
    local targets = {}
    package.loaded["wkddap.memory"] = {
      open = function(target)
        targets[#targets + 1] = target
      end,
    }
    vim.cmd("Dap memory &buffer[4]")
    vim.cmd("Dap memory")
    package.loaded["wkddap.memory"] = nil

    assert.are.same({ "&buffer[4]", "" }, targets)
  end)

  it(":Dap memory-window opens the view in a companion window", function()
    reload().setup()
    local calls = {}
    package.loaded["wkddap.memory"] = {
      open = function(target, opts)
        calls[#calls + 1] = { target = target, opts = opts }
      end,
    }
    vim.cmd("Dap memory-window &buffer")
    vim.cmd("Dap memory-window")
    package.loaded["wkddap.memory"] = nil

    assert.are.same({
      { target = "&buffer", opts = { companion = true } },
      { target = "", opts = { companion = true } },
    }, calls)
  end)

  it("does not register any subcommand outside the expected set", function()
    reload().setup()
    local completions = vim.fn.getcompletion("Dap ", "cmdline")

    for _, sub in ipairs(completions) do
      assert.is_true(
        vim.tbl_contains(EXPECTED_SUBCOMMANDS, sub),
        string.format("unexpected :Dap subcommand: %q", sub)
      )
    end
  end)
end)
