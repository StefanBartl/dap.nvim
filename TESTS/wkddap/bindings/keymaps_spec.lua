--- Covers wkddap.bindings.keymaps.setup(): it requires nvim-dap eagerly (so
--- it's stubbed here, per TESTS/README.md), then registers through the real
--- lib.nvim.bindings.keymap registry -- exercised for real, not mocked,
--- since it's a genuine dap.nvim dependency and its own logic (prefixing,
--- per-action override/disable) is exactly what's worth covering here.

local keymaps = require("wkddap.bindings.keymaps")

--- A minimal but complete nvim-dap stand-in: every field keymaps.setup()
--- references, either directly as an rhs or inside the counted_step/listener
--- wiring.
local function fake_dap()
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

describe("wkddap.bindings.keymaps.setup()", function()
  before_each(function()
    package.loaded["dap"] = fake_dap()
  end)

  after_each(function()
    package.loaded["dap"] = nil
  end)

  it(
    "registers one entry per action, with eval's n/v binds counted separately (14 total)",
    function()
      local bound = keymaps.setup({ prefix = "<leader>d" }, false)
      assert.are.equal(14, #bound)
    end
  )

  it("binds every enabled action under the configured prefix", function()
    local bound = keymaps.setup({ prefix = "<leader>z" }, false)

    local by_name = {}
    for _, entry in ipairs(bound) do
      by_name[entry.name] = by_name[entry.name] or {}
      table.insert(by_name[entry.name], entry)
    end

    assert.are.equal("<leader>zc", by_name.continue[1].lhs)
    assert.is_true(by_name.continue[1].bound)
    assert.are.equal("<leader>zb", by_name.toggle_breakpoint[1].lhs)
  end)

  it("eval binds the same key in both normal and visual mode", function()
    local bound = keymaps.setup({ prefix = "<leader>d" }, false)

    local eval_entries = {}
    for _, entry in ipairs(bound) do
      if entry.name == "eval" then
        table.insert(eval_entries, entry)
      end
    end

    assert.are.equal(2, #eval_entries)
    local modes = { eval_entries[1].mode, eval_entries[2].mode }
    table.sort(modes)
    assert.are.same({ "n", "v" }, modes)
    assert.are.equal("<leader>de", eval_entries[1].lhs)
    assert.are.equal("<leader>de", eval_entries[2].lhs)
  end)

  it("an action overridden to false is recorded but not bound", function()
    local bound = keymaps.setup({ prefix = "<leader>d", conditional_breakpoint = false }, false)

    local found
    for _, entry in ipairs(bound) do
      if entry.name == "conditional_breakpoint" then
        found = entry
      end
    end

    assert.is_not_nil(found)
    assert.is_nil(found.lhs)
    assert.is_false(found.bound)
  end)

  it("an action remapped to a custom lhs binds there instead of its default", function()
    local bound = keymaps.setup({ prefix = "<leader>d", restart = "<leader>zr" }, false)

    local found
    for _, entry in ipairs(bound) do
      if entry.name == "restart" then
        found = entry
      end
    end

    assert.are.equal("<leader>zr", found.lhs)
    assert.is_true(found.bound)
  end)
end)
