--- Covers wkddap.core.init's sole job: delegate to wkddap.core.setup.setup(),
--- forwarding opts and its return value unchanged, and fail closed if that
--- module can't be required at all.

local function reload()
  package.loaded["wkddap.core"] = nil
  return require("wkddap.core")
end

describe("wkddap.core", function()
  after_each(function()
    package.loaded["wkddap.core.setup"] = nil
  end)

  it("forwards opts to wkddap.core.setup.setup() and returns its result unchanged", function()
    local received_opts
    package.loaded["wkddap.core.setup"] = {
      setup = function(opts)
        received_opts = opts
        return true
      end,
    }

    local core = reload()
    local opts = { log_level = 2 }
    assert.is_true(core.setup(opts))
    assert.are.equal(opts, received_opts)
  end)

  it("propagates a false result from wkddap.core.setup.setup()", function()
    package.loaded["wkddap.core.setup"] = {
      setup = function(_)
        return false
      end,
    }

    local core = reload()
    assert.is_false(core.setup({}))
  end)
end)
