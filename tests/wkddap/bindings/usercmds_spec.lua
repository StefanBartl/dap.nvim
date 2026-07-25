--- Covers bindings.usercmds.setup(): all 13 :Dap routes register and show
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
