--- Covers wkddap.integrations.menu: the config.menu.enable and dap-presence
--- gates, and the shape M.items()/M.submenu() hand back to a host menu
--- plugin.
---
--- `ui.contextmenu` is required unconditionally at module load (not pcall'd,
--- unlike every other soft dependency in this plugin), so it must be stubbed
--- in package.loaded *before* the module is (re)required -- an absent real
--- nvzone/menu install would otherwise fail the require itself.

local function fake_contextmenu()
  return {
    group = function(out, ...)
      for _, entry in ipairs({ ... }) do
        table.insert(out, entry)
      end
    end,
    entry = function(enabled, label, fn, keys)
      return { enabled = enabled, label = label, fn = fn, keys = keys }
    end,
    submenu = function(label, items)
      return { label = label, items = items }
    end,
  }
end

local function reload()
  package.loaded["wkddap.integrations.menu"] = nil
  package.loaded["ui.contextmenu"] = fake_contextmenu()
  return require("wkddap.integrations.menu")
end

describe("wkddap.integrations.menu", function()
  before_each(function()
    package.loaded["wkddap.config"] = nil
  end)

  after_each(function()
    package.loaded["ui.contextmenu"] = nil
    package.loaded["dap"] = nil
    package.loaded["wkddap.config"] = nil
  end)

  it("items() returns an empty list when config.menu.enable is false", function()
    require("wkddap.config").setup({ menu = { enable = false } })
    local menu = reload()

    assert.are.same({}, menu.items())
  end)

  it("enabled() is what ui.menu asks: true by default, off with either switch", function()
    require("wkddap.config").setup({})
    local menu = reload()
    assert.is_true(menu.enabled())

    require("wkddap.config").setup({ integrations = { ui_menu = false } })
    assert.is_false(menu.enabled())

    require("wkddap.config").setup({ menu = { enable = false } })
    assert.is_false(menu.enabled())
  end)

  it("integrations.ui_menu = false leaves items() to other hosts", function()
    require("wkddap.config").setup({ integrations = { ui_menu = false } })
    package.loaded["dap"] = {
      continue = function() end,
      step_over = function() end,
      step_into = function() end,
      step_out = function() end,
      terminate = function() end,
      restart = function() end,
      toggle_breakpoint = function() end,
      set_breakpoint = function() end,
      clear_breakpoints = function() end,
      run_to_cursor = function() end,
      repl = { toggle = function() end },
    }
    local menu = reload()
    assert.is_true(#menu.items() > 0)
  end)

  it("items() returns an empty list when nvim-dap isn't installed", function()
    require("wkddap.config").setup({ menu = { enable = true } })
    package.loaded["dap"] = nil
    local menu = reload()

    assert.are.same({}, menu.items())
  end)

  it("items() returns every session/breakpoint/UI entry once dap is available", function()
    require("wkddap.config").setup({ menu = { enable = true } })
    package.loaded["dap"] = {
      continue = function() end,
      step_over = function() end,
      step_into = function() end,
      step_out = function() end,
      terminate = function() end,
      restart = function() end,
      toggle_breakpoint = function() end,
      list_breakpoints = function() end,
    }
    local menu = reload()

    local items = menu.items()
    -- 6 session-control + 4 breakpoint + 2 panel-UI entries.
    assert.are.equal(12, #items)
    for _, item in ipairs(items) do
      assert.is_true(item.enabled)
      assert.are.equal("string", type(item.label))
    end
  end)

  describe("key hints", function()
    local function full_dap()
      return {
        continue = function() end,
        step_over = function() end,
        step_into = function() end,
        step_out = function() end,
        terminate = function() end,
        restart = function() end,
        toggle_breakpoint = function() end,
        list_breakpoints = function() end,
        repl = { open = function() end },
        listeners = { after = {}, before = {} },
      }
    end

    ---@return table<string, string|false> label -> keys (false when none)
    local function hints_by_label(items)
      local out = {}
      for _, item in ipairs(items) do
        out[vim.trim(item.label)] = item.keys or false
      end
      return out
    end

    after_each(function()
      require("lib.nvim.bindings.keymap").forget("DAP")
    end)

    it("follow keymaps.prefix and per-action overrides; a key set to false shows none", function()
      require("wkddap.config").setup({
        keymaps = {
          enable = true,
          prefix = "<leader>da",
          toggle_breakpoint = "<F9>",
          restart = false,
        },
      })
      package.loaded["dap"] = full_dap()
      local cfg = require("wkddap.config").get()
      require("wkddap.bindings.keymaps").setup(cfg.keymaps, false)
      local menu = reload()

      local hints = hints_by_label(menu.items())
      assert.are.equal("<leader>dac", hints["Continue"])
      assert.are.equal("<leader>das", hints["Step Over"])
      assert.are.equal("<leader>dae", hints["Evaluate Expression / Selection"])
      assert.are.equal("<F9>", hints["Toggle Breakpoint"])
      assert.is_false(hints["Restart"])
    end)

    it("show nothing when keymaps.enable is false", function()
      require("wkddap.config").setup({ keymaps = { enable = false } })
      package.loaded["dap"] = full_dap()
      local menu = reload()

      for label, keys in pairs(hints_by_label(menu.items())) do
        assert.is_false(keys, label)
      end
    end)
  end)

  it("submenu() wraps items() as a single labeled entry", function()
    require("wkddap.config").setup({ menu = { enable = true } })
    package.loaded["dap"] = nil -- items() -> {} is enough to check the wrapping shape
    local menu = reload()

    local sub = menu.submenu()
    assert.are.equal("  DAP", sub.label)
    assert.are.same({}, sub.items)
  end)

  it("submenu() accepts a custom label", function()
    require("wkddap.config").setup({ menu = { enable = true } })
    package.loaded["dap"] = nil
    local menu = reload()

    assert.are.equal("Debug", menu.submenu("Debug").label)
  end)
end)
