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

describe("wkddap.languages: javascript and browser share dap.configurations keys", function()
  before_each(function()
    package.loaded["dap"] = { configurations = {} }
  end)

  after_each(function()
    package.loaded["dap"] = nil
  end)

  it("keeps both modules' entries whichever loads second", function()
    -- The default order is javascript before browser; the reverse used to
    -- wipe the browser entries for javascript/typescript because
    -- javascript.load() assigned the key instead of appending to it.
    reload("browser").load()
    reload("javascript").load()

    local dap = package.loaded["dap"]
    for _, ft in ipairs({ "javascript", "typescript" }) do
      local types = {}
      for _, entry in ipairs(dap.configurations[ft]) do
        types[entry.type] = (types[entry.type] or 0) + 1
      end
      assert.are.same({ ["pwa-chrome"] = 2, ["pwa-node"] = 2 }, types, ft)
    end
  end)
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

describe("wkddap.languages.rust load(): initCommands and the sysroot cache", function()
  local orig_system, orig_notify

  --- Stub rustc as present and `rustc --print sysroot` as answering
  --- `sysroot`, counting the spawns; the sysroot cache is keyed by
  --- paths.workspace_root(), which is stubbed to `cwd` (mutable via the
  --- returned setter).
  ---@param sysroot string
  ---@return fun(): integer spawns, fun(dir: string) set_cwd
  local function stub_toolchain(sysroot)
    local spawns, cwd = 0, "/proj/a"
    package.loaded["wkddap.utils.executable"] = {
      exists = function(_)
        return true
      end,
    }
    package.loaded["wkddap.utils.paths"] = {
      workspace_root = function()
        return cwd
      end,
      normalize = function(p)
        return p
      end,
      join = function(...)
        return table.concat({ ... }, "/")
      end,
    }
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.system = function(_argv, _opts, on_exit)
      spawns = spawns + 1
      local res = { code = 0, stdout = sysroot .. "\n", stderr = "" }
      if on_exit then
        on_exit(res)
      end
      return {
        wait = function()
          return res
        end,
      }
    end
    return function()
      return spawns
    end, function(dir)
      cwd = dir
    end
  end

  before_each(function()
    orig_system, orig_notify = vim.system, vim.notify
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function() end
    package.loaded["dap"] = { configurations = {} }
  end)

  after_each(function()
    vim.system, vim.notify = orig_system, orig_notify
    package.loaded["dap"] = nil
    package.loaded["wkddap.utils.executable"] = nil
    package.loaded["wkddap.utils.paths"] = nil
  end)

  local function init_commands()
    local rust = reload("rust")
    rust.load()
    return package.loaded["dap"].configurations.rust[1].initCommands
  end

  it("returns no commands at all when rustc is unavailable", function()
    package.loaded["wkddap.utils.executable"] = {
      exists = function(_)
        return false
      end,
    }
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.system = function()
      error("must not be spawned without rustc")
    end

    assert.are.same({}, init_commands()())
  end)

  it("imports lldb_lookup.py from the sysroot rustc reports", function()
    stub_toolchain("/toolchains/stable")

    local commands = init_commands()()
    assert.are.equal(
      'command script import "/toolchains/stable/lib/rustlib/etc/lldb_lookup.py"',
      commands[1]
    )
  end)

  it("caches the sysroot per working directory, not once per session", function()
    local spawns, set_cwd = stub_toolchain("/toolchains/stable")
    local commands = init_commands()

    commands()
    commands()
    assert.are.equal(1, spawns(), "second session in the same directory reuses the answer")

    set_cwd("/proj/b")
    commands()
    assert.are.equal(2, spawns(), "another directory may have another toolchain")
  end)

  it("does not remember a failed lookup", function()
    local spawns = stub_toolchain("")
    local commands = init_commands()

    assert.are.same({}, commands())
    commands()
    assert.are.equal(2, spawns(), "an empty answer is retried, not cached")
  end)
end)
