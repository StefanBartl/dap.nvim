--- Covers wkddap.utils.mason.ensure_installed(): the mason.nvim presence
--- gate, the "nothing missing" no-op, and the missing-package
--- dedup/sort/install list -- all stubbed (mason.nvim, wkddap.config,
--- wkddap.registry) so the outcome doesn't depend on what's actually
--- installed on the machine running the suite.

local function reload()
  package.loaded["wkddap.utils.mason"] = nil
  return require("wkddap.utils.mason")
end

describe("wkddap.utils.mason.ensure_installed()", function()
  local original_vim_cmd

  before_each(function()
    original_vim_cmd = vim.cmd
    _G.__vim_cmd_calls = {}
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.cmd = function(cmd)
      table.insert(_G.__vim_cmd_calls, cmd)
    end
  end)

  after_each(function()
    vim.cmd = original_vim_cmd
    package.loaded["mason"] = nil
    package.loaded["wkddap.config"] = nil
    package.loaded["wkddap.registry"] = nil
    _G.__vim_cmd_calls = nil
  end)

  it("does nothing (no :MasonInstall) when mason.nvim isn't installed", function()
    package.loaded["mason"] = nil
    local mason = reload()

    mason.ensure_installed({ "python" })
    assert.are.equal(0, #_G.__vim_cmd_calls)
  end)

  it("does nothing when every requested adapter already resolves", function()
    package.loaded["mason"] = {}
    package.loaded["wkddap.config"] = {
      language_aliases = {},
      adapter_binaries = {
        python = { type = "binary", mason_pkg = "debugpy" },
      },
      get_adapter_path = function(_)
        return "/already/installed/debugpy"
      end,
    }
    local mason = reload()

    mason.ensure_installed({ "python" })
    assert.are.equal(0, #_G.__vim_cmd_calls)
  end)

  it("installs missing required adapters, deduped across aliased languages, sorted", function()
    package.loaded["mason"] = {}
    package.loaded["wkddap.config"] = {
      language_aliases = { rust = "compiled", zig = "compiled" },
      adapter_binaries = {
        compiled = { type = "binary", mason_pkg = "codelldb" },
        go = { type = "binary", mason_pkg = "delve" },
      },
      get_adapter_path = function(_)
        return nil
      end,
    }
    local mason = reload()

    -- "rust" and "zig" both alias to "compiled" (both need codelldb) -- the
    -- install list must dedup them into one package, not request it twice.
    mason.ensure_installed({ "rust", "zig", "go" })

    assert.are.equal(1, #_G.__vim_cmd_calls)
    assert.are.equal("MasonInstall codelldb delve", _G.__vim_cmd_calls[1])
  end)

  it("skips adapters without a mason_pkg (nothing Mason could install for them)", function()
    package.loaded["mason"] = {}
    package.loaded["wkddap.config"] = {
      language_aliases = {},
      adapter_binaries = {
        assembly = { type = "binary" }, -- no mason_pkg: gdb has no Mason package
      },
      get_adapter_path = function(_)
        return nil
      end,
    }
    local mason = reload()

    mason.ensure_installed({ "assembly" })
    assert.are.equal(0, #_G.__vim_cmd_calls)
  end)

  it("defaults to every available language when called with an empty list", function()
    package.loaded["mason"] = {}
    package.loaded["wkddap.registry"] = {
      available_languages = function()
        return { "python" }
      end,
    }
    package.loaded["wkddap.config"] = {
      language_aliases = {},
      adapter_binaries = {
        python = { type = "binary", mason_pkg = "debugpy" },
      },
      get_adapter_path = function(_)
        return nil
      end,
    }
    local mason = reload()

    mason.ensure_installed({})
    assert.are.equal(1, #_G.__vim_cmd_calls)
    assert.are.equal("MasonInstall debugpy", _G.__vim_cmd_calls[1])
  end)
end)
