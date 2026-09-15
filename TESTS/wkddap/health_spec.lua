--- Smoke test for wkddap.health.check(): every soft dependency it probes is
--- absent in this environment (per TESTS/README.md), so this only asserts
--- that :checkhealth wkddap runs to completion without erroring -- the
--- individual vim.health.ok/warn/info reports it produces are exercised
--- indirectly through wkddap.config/wkddap.registry, which have their own
--- specs.

describe("wkddap.health.check()", function()
  it("runs to completion without error when no companion plugin is installed", function()
    local health = require("wkddap.health")
    assert.has_no.errors(function()
      health.check()
    end)
  end)
end)
