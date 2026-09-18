--- Generic structural contract shared by all 11 `wkddap.languages.*` modules,
--- instead of 11 near-duplicate spec files: each module exposes `setup()` +
--- `load()`, `load()` needs only `dap` (stubbed as a plain table, never a
--- real nvim-dap install) to populate `dap.configurations[key]` for its
--- filetype key(s) with well-formed entries. This spec only exercises that
--- shared shape; per-language deviations (the async `program()` prompts, the
--- adapter-availability gate in `setup()`) live in adapter_setup_spec.lua and
--- the pre-existing program_prompt_spec.lua.

--- Every language module, the `dap.configurations` key(s) `load()` populates,
--- and how many entries each key ends up with.
---@type { mod: string, keys: string[], counts?: table<string, integer> }[]
local LANGUAGES = {
  { mod = "python", keys = { "python" } },
  { mod = "go", keys = { "go" }, counts = { go = 3 } },
  {
    mod = "javascript",
    keys = { "javascript", "typescript" },
    counts = { javascript = 2, typescript = 2 },
  },
  { mod = "bash", keys = { "sh", "bash", "zsh", "ksh" } },
  { mod = "c", keys = { "c", "cpp" } },
  { mod = "csharp", keys = { "cs", "fsharp" } },
  {
    mod = "browser",
    keys = { "javascript", "typescript", "javascriptreact", "typescriptreact", "astro" },
    counts = { javascript = 2, typescript = 2, javascriptreact = 2, typescriptreact = 2, astro = 2 },
  },
  { mod = "lua", keys = { "lua" }, counts = { lua = 2 } },
  { mod = "zig", keys = { "zig" }, counts = { zig = 2 } },
  { mod = "rust", keys = { "rust" } },
  { mod = "assembly", keys = { "asm", "nasm", "gas" } },
}

--- `request` values nvim-dap actually understands; every config entry across
--- every language must use one of these.
local VALID_REQUESTS = { launch = true, attach = true }

local function reload(mod)
  package.loaded["wkddap.languages." .. mod] = nil
  return require("wkddap.languages." .. mod)
end

describe("wkddap.languages: shared module shape", function()
  for _, lang in ipairs(LANGUAGES) do
    it(("%s exposes setup() and load() as functions"):format(lang.mod), function()
      local m = reload(lang.mod)
      assert.are.equal("function", type(m.setup))
      assert.are.equal("function", type(m.load))
    end)
  end
end)

describe("wkddap.languages: setup()/load() require dap", function()
  for _, lang in ipairs(LANGUAGES) do
    it(
      ("%s.setup() and .load() both return false without dap/its tool available"):format(lang.mod),
      function()
        package.loaded["dap"] = nil
        local m = reload(lang.mod)
        assert.is_false((m.setup()))
        assert.is_false((m.load()))
      end
    )
  end
end)

describe("wkddap.languages: load() populates well-formed configurations", function()
  before_each(function()
    package.loaded["dap"] = { configurations = {} }
  end)

  after_each(function()
    package.loaded["dap"] = nil
  end)

  for _, lang in ipairs(LANGUAGES) do
    it(("%s.load() returns true and fills every expected key"):format(lang.mod), function()
      local m = reload(lang.mod)
      assert.is_true((m.load()))

      local dap = package.loaded["dap"]
      for _, key in ipairs(lang.keys) do
        local entries = dap.configurations[key]
        assert.is_table(entries, ("dap.configurations.%s should be a table"):format(key))
        assert.is_true(#entries > 0, ("dap.configurations.%s should be non-empty"):format(key))

        local expected_count = lang.counts and lang.counts[key]
        if expected_count then
          assert.are.equal(
            expected_count,
            #entries,
            ("dap.configurations.%s entry count"):format(key)
          )
        end

        for i, entry in ipairs(entries) do
          local where = ("%s configurations.%s[%d]"):format(lang.mod, key, i)
          assert.are.equal("string", type(entry.type), where .. ".type")
          assert.are.equal("string", type(entry.name), where .. ".name")
          assert.are.equal("string", type(entry.request), where .. ".request")
          assert.is_true(
            VALID_REQUESTS[entry.request] == true,
            where .. ".request must be launch|attach"
          )
        end
      end
    end)
  end
end)

describe("wkddap.languages.bash load(): bash/bashdb paths", function()
  before_each(function()
    package.loaded["dap"] = { configurations = {} }
  end)

  after_each(function()
    package.loaded["dap"] = nil
    package.loaded["wkddap.utils.executable"] = nil
  end)

  it("resolves pathBash/pathBashdb through the memoized executable lookup", function()
    package.loaded["wkddap.utils.executable"] = {
      path = function(name)
        return name == "bash" and "/usr/bin/bash" or nil
      end,
    }
    local bash = reload("bash")
    bash.load()

    local entry = package.loaded["dap"].configurations.bash[1]
    assert.are.equal("/usr/bin/bash", entry.pathBash)
    -- A miss must stay the empty string the adapter treats as "use the
    -- bundled bashdb", never nil.
    assert.are.equal("", entry.pathBashdb)
  end)
end)
