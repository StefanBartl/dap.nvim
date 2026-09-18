--- Covers wkddap.core.setup.setup(): the nvim-dap presence gate, the
--- opts.log_level -> dap.set_log_level() hand-over, and that capabilities/
--- state get initialized (via pcall, so a broken one doesn't abort the rest).

local function reload()
  package.loaded["wkddap.core.setup"] = nil
  return require("wkddap.core.setup")
end

--- A `dap` stub that records what set_log_level() receives.
---@return table dap, fun(): any received
local function dap_with_log_level()
  local received
  local dap = {
    set_log_level = function(level)
      received = level
    end,
  }
  return dap, function()
    return received
  end
end

describe("wkddap.core.setup", function()
  before_each(function()
    package.loaded["wkddap.core.state"] = nil
  end)

  after_each(function()
    package.loaded["dap"] = nil
  end)

  it("returns false when nvim-dap isn't installed", function()
    package.loaded["dap"] = nil
    local setup = reload()
    assert.is_false(setup.setup({}))
  end)

  it("returns true and initializes state once dap is present", function()
    package.loaded["dap"] = {}
    local setup = reload()

    assert.is_true(setup.setup({}))
    assert.is_true(require("wkddap.core.state").is_initialized())
  end)

  describe("opts.log_level", function()
    local orig_notify = vim.notify

    before_each(function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function() end
    end)

    after_each(function()
      vim.notify = orig_notify
    end)

    it("hands a vim.log.levels value to dap.set_log_level() as nvim-dap's level name", function()
      local dap, received = dap_with_log_level()
      package.loaded["dap"] = dap
      local setup = reload()

      setup.setup({ log_level = vim.log.levels.DEBUG })
      assert.are.equal("DEBUG", received())
    end)

    it("accepts a level name and upper-cases it for nvim-dap", function()
      local dap, received = dap_with_log_level()
      package.loaded["dap"] = dap
      local setup = reload()

      setup.setup({ log_level = "warn" })
      assert.are.equal("WARN", received())
    end)

    it("maps vim.log.levels.OFF, which nvim-dap lacks, to its quietest level", function()
      local dap, received = dap_with_log_level()
      package.loaded["dap"] = dap
      local setup = reload()

      setup.setup({ log_level = vim.log.levels.OFF })
      assert.are.equal("ERROR", received())
    end)

    it("leaves nvim-dap's level alone when opts.log_level is nil", function()
      local dap, received = dap_with_log_level()
      package.loaded["dap"] = dap
      local setup = reload()

      setup.setup({})
      assert.is_nil(received())
    end)

    it("leaves nvim-dap's level alone for a value that is not a level", function()
      local dap, received = dap_with_log_level()
      package.loaded["dap"] = dap
      local setup = reload()

      setup.setup({ log_level = "loud" })
      assert.is_nil(received())
    end)

    it("does not write NVIM_DAP_LOG_LEVEL (nvim-dap never read it)", function()
      local dap = dap_with_log_level()
      package.loaded["dap"] = dap
      local setup = reload()

      setup.setup({ log_level = vim.log.levels.DEBUG })
      assert.is_nil(vim.env.NVIM_DAP_LOG_LEVEL)
    end)

    it("survives a dap module without set_log_level()", function()
      package.loaded["dap"] = {}
      local setup = reload()

      assert.has_no.errors(function()
        setup.setup({ log_level = vim.log.levels.DEBUG })
      end)
    end)
  end)
end)
