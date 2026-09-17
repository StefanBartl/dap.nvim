--- Covers wkddap's top-level M.setup() orchestration.
---
--- Most of it is exercised here with *nothing* stubbed at all: every step
--- from core init through adapters/configurations/ui/bindings is written to
--- degrade gracefully (pcall'd, or itself pcall-guarded) when nvim-dap and
--- every adapter binary are absent -- which is exactly this test
--- environment, per TESTS/README.md -- so a real, unmocked `setup({})` call
--- is itself a meaningful smoke test of that contract holding end-to-end.

local function reload()
  package.loaded["wkddap"] = nil
  return require("wkddap")
end

describe("wkddap.setup(): real end-to-end smoke test (no plugins installed)", function()
  after_each(function()
    vim.g.loaded_wkddap = nil
  end)

  it("completes successfully and reports itself initialized", function()
    local wkddap = reload()

    assert.is_true(wkddap.setup({}))
    assert.is_true(wkddap.is_initialized())
    assert.are.equal(1, vim.g.loaded_wkddap)
    assert.are.equal("dap-view", wkddap.get_config().ui.provider)
  end)

  it("rejects a second setup() call while already initialized", function()
    local wkddap = reload()
    wkddap.setup({})

    assert.is_false(wkddap.setup({}))
  end)

  it("available_languages() delegates to the registry's fixed list", function()
    local wkddap = reload()
    local registry = require("wkddap.registry")

    assert.are.same(registry.available_languages(), wkddap.available_languages())
  end)

  it("enabled_languages() delegates to the registry's (empty, nothing registered) list", function()
    local wkddap = reload()
    local registry = require("wkddap.registry")

    assert.are.same(registry.enabled_languages(), wkddap.enabled_languages())
  end)

  it("get_config() is nil before the first setup() call", function()
    local wkddap = reload()
    assert.is_nil(wkddap.get_config())
  end)
end)

describe(
  "wkddap.setup(): core.setup() returning false does not stop the rest of setup()",
  function()
    after_each(function()
      package.loaded["wkddap.core"] = nil
      vim.g.loaded_wkddap = nil
    end)

    it("still completes and reports initialized", function()
      -- wkddap.init only pcall's the *call* to core.setup(), not its return
      -- value: `pcall(core.setup, cfg)` succeeds (no error thrown) whether
      -- core.setup() returns true or false, so a graceful "nvim-dap missing"
      -- false from it is not actually load-bearing here.
      package.loaded["wkddap.core"] = {
        setup = function(_cfg)
          return false
        end,
      }
      local wkddap = reload()

      assert.is_true(wkddap.setup({}))
      assert.is_true(wkddap.is_initialized())
    end)
  end
)

describe("wkddap.setup(): auto_install", function()
  after_each(function()
    package.loaded["wkddap.utils.mason"] = nil
    vim.g.loaded_wkddap = nil
  end)

  it(
    "calls wkddap.utils.mason.ensure_installed(cfg.languages) when auto_install is true",
    function()
      local received_languages
      package.loaded["wkddap.utils.mason"] = {
        ensure_installed = function(languages)
          received_languages = languages
        end,
      }
      local wkddap = reload()

      wkddap.setup({ auto_install = true, languages = { "python", "go" } })
      assert.are.same({ "python", "go" }, received_languages)
    end
  )

  it("does not call it when auto_install is false (the default)", function()
    local called = false
    package.loaded["wkddap.utils.mason"] = {
      ensure_installed = function(_)
        called = true
      end,
    }
    local wkddap = reload()

    wkddap.setup({})
    assert.is_false(called)
  end)
end)
