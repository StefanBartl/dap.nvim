--- Covers wkddap.adapters.register_all(): delegates each language to
--- wkddap.registry.register(), defaults to every available language when
--- none are given, and always returns true regardless of failures (the
--- per-language reason is only surfaced via the summary notify.warn / later
--- :checkhealth, not the return value).

local function reload()
  package.loaded["wkddap.adapters"] = nil
  return require("wkddap.adapters")
end

describe("wkddap.adapters.register_all()", function()
  after_each(function()
    package.loaded["wkddap.registry"] = nil
  end)

  it("calls registry.register() once per requested language", function()
    local calls = {}
    package.loaded["wkddap.registry"] = {
      register = function(lang)
        table.insert(calls, lang)
        return true
      end,
    }
    local adapters = reload()

    assert.is_true(adapters.register_all({ "python", "go" }))
    assert.are.same({ "python", "go" }, calls)
  end)

  it("defaults to registry.available_languages() when given an empty/nil list", function()
    local calls = {}
    package.loaded["wkddap.registry"] = {
      available_languages = function()
        return { "lua", "rust" }
      end,
      register = function(lang)
        table.insert(calls, lang)
        return true
      end,
    }
    local adapters = reload()

    adapters.register_all({})
    assert.are.same({ "lua", "rust" }, calls)

    calls = {}
    adapters.register_all(nil)
    assert.are.same({ "lua", "rust" }, calls)
  end)

  it("returns true even when every language fails to register", function()
    package.loaded["wkddap.registry"] = {
      register = function(_)
        return false
      end,
    }
    local adapters = reload()

    assert.is_true(adapters.register_all({ "python", "go" }))
  end)
end)

describe("wkddap.adapters.register_all(): custom adapter overrides", function()
  before_each(function()
    package.loaded["wkddap.registry"] = {
      register = function(_)
        return true
      end,
    }
  end)

  after_each(function()
    package.loaded["wkddap.registry"] = nil
    package.loaded["dap"] = nil
  end)

  it("deep-merges a table override over the adapter a language module registered", function()
    package.loaded["dap"] = {
      adapters = {
        codelldb = {
          type = "server",
          port = "${port}",
          executable = { command = "/mason/codelldb", args = { "--port", "${port}" } },
        },
      },
    }
    local adapters = reload()

    adapters.register_all({ "rust" }, {
      codelldb = { executable = { command = "/usr/local/bin/codelldb" } },
    })

    local codelldb = package.loaded["dap"].adapters.codelldb
    assert.are.equal("/usr/local/bin/codelldb", codelldb.executable.command)
    assert.are.same({ "--port", "${port}" }, codelldb.executable.args)
    assert.are.equal("server", codelldb.type)
  end)

  it("adds an adapter nothing registered, and a function override replaces as given", function()
    package.loaded["dap"] = { adapters = { nlua = function() end } }
    local adapters = reload()

    local custom = function() end
    adapters.register_all({ "lua" }, {
      nlua = custom,
      mine = { type = "executable", command = "my-adapter" },
    })

    assert.are.equal(custom, package.loaded["dap"].adapters.nlua)
    assert.are.equal("my-adapter", package.loaded["dap"].adapters.mine.command)
  end)

  it("does not touch dap.adapters (or require dap) when no overrides are given", function()
    package.loaded["dap"] = nil
    local adapters = reload()

    assert.has_no.errors(function()
      adapters.register_all({ "go" }, {})
      adapters.register_all({ "go" }, nil)
    end)
  end)
end)
