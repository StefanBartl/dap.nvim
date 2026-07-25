--- Covers helptags.generate(): doc/tags gets (re)created from doc/wkddap.txt
--- via the repo's own doc/ dir, resolved through 'runtimepath' (minimal_init
--- prepends the repo root, same as a real plugin manager would).

describe("wkddap.utils.helptags", function()
  local doc_dir = vim.fn.getcwd() .. "/doc"
  local tags_path = doc_dir .. "/tags"

  local function reload()
    package.loaded["wkddap.utils.helptags"] = nil
    return require("wkddap.utils.helptags")
  end

  before_each(function()
    vim.fn.delete(tags_path)
  end)

  after_each(function()
    vim.fn.delete(tags_path)
  end)

  it("generates doc/tags when it is missing", function()
    assert.is_nil(vim.uv.fs_stat(tags_path))

    reload().generate()

    assert.is_not_nil(vim.uv.fs_stat(tags_path))
  end)

  it("is idempotent: a second call does not error when tags is already current", function()
    local helptags = reload()
    helptags.generate()

    assert.has_no.errors(function()
      helptags.generate()
    end)
    assert.is_not_nil(vim.uv.fs_stat(tags_path))
  end)
end)
