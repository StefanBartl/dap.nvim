--- Covers wkddap.core.setup.setup(): the nvim-dap presence gate, the
--- NVIM_DAP_LOG_LEVEL env passthrough, and that capabilities/state get
--- initialized (via pcall, so a broken one doesn't abort the rest).

local function reload()
  package.loaded["wkddap.core.setup"] = nil
  return require("wkddap.core.setup")
end

describe("wkddap.core.setup", function()
  before_each(function()
    package.loaded["wkddap.core.state"] = nil
  end)

  after_each(function()
    package.loaded["dap"] = nil
    vim.env.NVIM_DAP_LOG_LEVEL = nil
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

  it("sets NVIM_DAP_LOG_LEVEL from opts.log_level", function()
    package.loaded["dap"] = {}
    local setup = reload()

    setup.setup({ log_level = 3 })
    assert.are.equal("3", vim.env.NVIM_DAP_LOG_LEVEL)
  end)

  it("leaves NVIM_DAP_LOG_LEVEL untouched when opts.log_level is nil", function()
    package.loaded["dap"] = {}
    vim.env.NVIM_DAP_LOG_LEVEL = nil
    local setup = reload()

    setup.setup({})
    assert.is_nil(vim.env.NVIM_DAP_LOG_LEVEL)
  end)
end)
