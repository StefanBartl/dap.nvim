--- Covers wkddap.bindings.setup()'s orchestration: usercmds always run,
--- keymaps only when cfg.keymaps.enable is true (and degrade gracefully via
--- pcall when nvim-dap is missing, instead of aborting autocmds setup too),
--- autocmds always run with cfg.autocmds.

local function reload()
  package.loaded["wkddap.bindings"] = nil
  return require("wkddap.bindings")
end

describe("wkddap.bindings.setup()", function()
  before_each(function()
    package.loaded["wkddap.bindings.usercmds"] = nil
    package.loaded["wkddap.bindings.keymaps"] = nil
    package.loaded["wkddap.bindings.autocmds"] = nil
  end)

  after_each(function()
    package.loaded["wkddap.bindings.usercmds"] = nil
    package.loaded["wkddap.bindings.keymaps"] = nil
    package.loaded["wkddap.bindings.autocmds"] = nil
  end)

  it("always sets up usercmds and autocmds, and keymaps when enabled", function()
    local called = { usercmds = false, keymaps = false, autocmds_opts = nil }
    package.loaded["wkddap.bindings.usercmds"] = {
      setup = function()
        called.usercmds = true
      end,
    }
    package.loaded["wkddap.bindings.keymaps"] = {
      setup = function(_opts, _which_key)
        called.keymaps = true
        return {}
      end,
    }
    package.loaded["wkddap.bindings.autocmds"] = {
      setup = function(opts)
        called.autocmds_opts = opts
      end,
    }

    local bindings = reload()
    local autocmds_opts = { enable = true }
    bindings.setup({
      keymaps = { enable = true, prefix = "<leader>d" },
      which_key = { enable = false },
      autocmds = autocmds_opts,
    })

    assert.is_true(called.usercmds)
    assert.is_true(called.keymaps)
    assert.are.equal(autocmds_opts, called.autocmds_opts)
  end)

  it("skips keymaps entirely when cfg.keymaps.enable is false", function()
    local keymaps_called = false
    package.loaded["wkddap.bindings.usercmds"] = { setup = function() end }
    package.loaded["wkddap.bindings.keymaps"] = {
      setup = function()
        keymaps_called = true
        return {}
      end,
    }
    package.loaded["wkddap.bindings.autocmds"] = { setup = function() end }

    local bindings = reload()
    bindings.setup({
      keymaps = { enable = false, prefix = "<leader>d" },
      which_key = { enable = false },
      autocmds = { enable = false },
    })

    assert.is_false(keymaps_called)
  end)

  it("a keymaps.setup() error is swallowed (autocmds still runs)", function()
    local autocmds_called = false
    package.loaded["wkddap.bindings.usercmds"] = { setup = function() end }
    package.loaded["wkddap.bindings.keymaps"] = {
      setup = function()
        error("nvim-dap not installed")
      end,
    }
    package.loaded["wkddap.bindings.autocmds"] = {
      setup = function()
        autocmds_called = true
      end,
    }

    local bindings = reload()
    assert.has_no.errors(function()
      bindings.setup({
        keymaps = { enable = true, prefix = "<leader>d" },
        which_key = { enable = false },
        autocmds = { enable = false },
      })
    end)
    assert.is_true(autocmds_called)
  end)
end)
