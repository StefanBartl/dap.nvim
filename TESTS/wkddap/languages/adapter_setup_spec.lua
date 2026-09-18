--- Generic contract for `setup()` across `wkddap.languages.*`: with `dap`
--- available, most modules gate adapter registration on
--- `wkddap.config.get_adapter_path(<name>)` and skip it when the binary
--- can't be resolved. `wkddap.config` is stubbed here (never a real Mason
--- install/binary on PATH) so both branches are deterministic regardless of
--- what happens to be installed on the machine running the suite.
---
--- Two modules deviate from that gate and get their own spot checks instead
--- of being folded into the shared table below:
---   - assembly.lua never calls `get_adapter_path` at all -- it registers
---     `gdb` by literal command name unconditionally once `dap` is present.
---   - lua.lua gates on the `osv` plugin being requireable, not on
---     `config.get_adapter_path` -- it doesn't require `wkddap.config` at all.

--- Modules following the common `config.get_adapter_path(<adapter_name>)`
--- gate, the name each passes, and the adapter key(s) `setup()` registers.
---@type { mod: string, adapter_name: string, adapter_keys: string[] }[]
local GATED_LANGUAGES = {
  { mod = "python", adapter_name = "python", adapter_keys = { "python" } },
  { mod = "go", adapter_name = "go", adapter_keys = { "go" } },
  { mod = "javascript", adapter_name = "javascript", adapter_keys = { "pwa-node" } },
  { mod = "bash", adapter_name = "bash", adapter_keys = { "bashdb" } },
  { mod = "c", adapter_name = "c", adapter_keys = { "lldb", "codelldb" } },
  { mod = "csharp", adapter_name = "csharp", adapter_keys = { "coreclr" } },
  { mod = "browser", adapter_name = "browser", adapter_keys = { "pwa-chrome" } },
  { mod = "zig", adapter_name = "zig", adapter_keys = { "lldb" } },
  { mod = "rust", adapter_name = "rust", adapter_keys = { "codelldb" } },
}

local function reload(mod)
  package.loaded["wkddap.languages." .. mod] = nil
  return require("wkddap.languages." .. mod)
end

describe("wkddap.languages setup(): common config.get_adapter_path gate", function()
  before_each(function()
    package.loaded["dap"] = { adapters = {} }
  end)

  after_each(function()
    package.loaded["dap"] = nil
    package.loaded["wkddap.config"] = nil
  end)

  for _, lang in ipairs(GATED_LANGUAGES) do
    it(
      ("%s.setup() returns false when the adapter binary can't be resolved"):format(lang.mod),
      function()
        package.loaded["wkddap.config"] = {
          get_adapter_path = function(_)
            return nil
          end,
        }
        local m = reload(lang.mod)
        assert.is_false((m.setup()))
        assert.are.same({}, package.loaded["dap"].adapters)
      end
    )

    it(
      ("%s.setup() registers dap.adapters.%s once the binary resolves"):format(
        lang.mod,
        lang.adapter_keys[1]
      ),
      function()
        package.loaded["wkddap.config"] = {
          get_adapter_path = function(name)
            if name == lang.adapter_name then
              return "/fake/path/to/" .. name
            end
            return nil
          end,
        }
        local m = reload(lang.mod)
        assert.is_true((m.setup()))

        for _, key in ipairs(lang.adapter_keys) do
          assert.is_table(package.loaded["dap"].adapters[key], ("dap.adapters.%s"):format(key))
        end
      end
    )
  end
end)

describe(
  "wkddap.languages javascript/browser setup(): the resolved binary is the server",
  function()
    before_each(function()
      package.loaded["dap"] = { adapters = {} }
    end)

    after_each(function()
      package.loaded["dap"] = nil
      package.loaded["wkddap.config"] = nil
    end)

    -- Both used to launch `node <hardcoded Mason script path>` after gating on
    -- get_adapter_path(), so a PATH install passed the gate and then failed to
    -- start. What resolved must be what runs.
    for _, case in ipairs({
      { mod = "javascript", adapter_name = "javascript", key = "pwa-node" },
      { mod = "browser", adapter_name = "browser", key = "pwa-chrome" },
    }) do
      it(("%s.setup() launches the path get_adapter_path() resolved"):format(case.mod), function()
        package.loaded["wkddap.config"] = {
          get_adapter_path = function(name)
            return name == case.adapter_name and "/opt/js-debug/js-debug-adapter" or nil
          end,
        }
        local m = reload(case.mod)
        assert.is_true((m.setup()))

        local executable = package.loaded["dap"].adapters[case.key].executable
        assert.are.equal("/opt/js-debug/js-debug-adapter", executable.command)
        assert.are.same({ "${port}" }, executable.args)
      end)
    end
  end
)

describe("wkddap.languages.assembly setup(): deviates from the common gate", function()
  before_each(function()
    package.loaded["dap"] = { adapters = {} }
    -- Even with the adapter unresolvable everywhere else, assembly.lua never
    -- looks at config.get_adapter_path -- so this stub, which resolves
    -- nothing, is here to prove the point rather than to set up the success
    -- case.
    package.loaded["wkddap.config"] = {
      get_adapter_path = function(_)
        return nil
      end,
    }
  end)

  after_each(function()
    package.loaded["dap"] = nil
    package.loaded["wkddap.config"] = nil
  end)

  it(
    "registers gdb unconditionally once dap is present, regardless of adapter resolution",
    function()
      package.loaded["wkddap.languages.assembly"] = nil
      local assembly = require("wkddap.languages.assembly")

      assert.is_true((assembly.setup()))
      assert.are.equal("gdb", package.loaded["dap"].adapters.gdb.command)
    end
  )
end)

describe("wkddap.languages.lua setup(): gates on the osv plugin, not an adapter binary", function()
  after_each(function()
    package.loaded["dap"] = nil
    package.loaded["osv"] = nil
  end)

  it("returns false when osv isn't installed, even with dap present", function()
    package.loaded["dap"] = { adapters = {} }
    package.loaded["osv"] = nil
    package.loaded["wkddap.languages.lua"] = nil
    local lua_lang = require("wkddap.languages.lua")

    assert.is_false((lua_lang.setup()))
  end)

  it("registers the nlua adapter once osv is present", function()
    package.loaded["dap"] = { adapters = {} }
    package.loaded["osv"] = {}
    package.loaded["wkddap.languages.lua"] = nil
    local lua_lang = require("wkddap.languages.lua")

    assert.is_true((lua_lang.setup()))
    assert.are.equal("function", type(package.loaded["dap"].adapters.nlua))
  end)
end)

--- M.launch_server(): documented in docs/FEATURES/LANGUAGES.md as the entry
--- point a user calls (from the *target* Neovim being attached to, not the
--- one running dap.nvim) to start OSV's in-process debug server. No other
--- module in this repo calls it -- it has no caller to exercise it
--- transitively, unlike setup()/load(), which run through wkddap.setup().
describe("wkddap.languages.lua launch_server()", function()
  after_each(function()
    package.loaded["osv"] = nil
    package.loaded["wkddap.languages.lua"] = nil
  end)

  it("returns false without calling osv.launch() when osv isn't installed", function()
    package.loaded["osv"] = nil
    local lua_lang = require("wkddap.languages.lua")

    assert.is_false((lua_lang.launch_server()))
  end)

  it("launches on the given port and reports success", function()
    local received_opts
    package.loaded["osv"] = {
      launch = function(opts)
        received_opts = opts
      end,
    }
    local lua_lang = require("wkddap.languages.lua")

    assert.is_true((lua_lang.launch_server(9999)))
    assert.are.same({ port = 9999 }, received_opts)
  end)

  it("defaults to port 8086 when called without one", function()
    local received_opts
    package.loaded["osv"] = {
      launch = function(opts)
        received_opts = opts
      end,
    }
    local lua_lang = require("wkddap.languages.lua")

    assert.is_true((lua_lang.launch_server()))
    assert.are.same({ port = 8086 }, received_opts)
  end)
end)
