--- Covers wkddap.utils.paths: join()/workspace_root() are this module's own
--- logic; normalize() is a one-line delegation to lib.nvim.normalize, already
--- exercised indirectly (with real path values) by the existing
--- languages/program_prompt_spec.lua.

local paths = require("wkddap.utils.paths")

describe("wkddap.utils.paths.join()", function()
  it("joins segments with the platform path separator", function()
    local sep = package.config:sub(1, 1)
    assert.are.equal("a" .. sep .. "b" .. sep .. "c", paths.join("a", "b", "c"))
  end)

  it("returns a single segment unchanged", function()
    assert.are.equal("only", paths.join("only"))
  end)

  it("returns an empty string when called with no segments", function()
    assert.are.equal("", paths.join())
  end)

  it("a trailing empty segment produces a trailing separator (dir-with-slash idiom)", function()
    local sep = package.config:sub(1, 1)
    assert.are.equal("a" .. sep, paths.join("a", ""))
  end)
end)

describe("wkddap.utils.paths.workspace_root()", function()
  it("returns the current working directory", function()
    assert.are.equal(vim.fn.getcwd(), paths.workspace_root())
  end)
end)

describe("wkddap.utils.paths.normalize()", function()
  it("delegates to lib.nvim.normalize.normalize_path", function()
    local normalize = require("lib.nvim.normalize")
    assert.are.equal(normalize.normalize_path("a/b"), paths.normalize("a/b"))
  end)
end)

describe("wkddap.utils.paths.native()", function()
  it("uses backslashes on Windows and leaves the path alone elsewhere", function()
    local expected = require("lib.nvim.cross").is_windows() and "C:\\proj\\bin\\app.dll"
      or "C:/proj/bin/app.dll"
    assert.are.equal(expected, paths.native("C:/proj/bin/app.dll"))
  end)

  it("returns exactly one value (gsub's count is dropped)", function()
    assert.are.equal(1, select("#", paths.native("a/b")))
  end)
end)
