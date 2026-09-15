--- wkddap.utils.executable is a pure re-export of lib.nvim.cross.executable
--- (see its own header comment) -- this only pins the re-export identity, not
--- the underlying PATH/Mason resolution logic, which belongs to lib.nvim.

local executable = require("wkddap.utils.executable")
local cross_executable = require("lib.nvim.cross.executable")

describe("wkddap.utils.executable", function()
  it("re-exports exists/path/mason_path from lib.nvim.cross.executable", function()
    assert.are.equal(cross_executable.exists, executable.exists)
    assert.are.equal(cross_executable.path, executable.path)
    assert.are.equal(cross_executable.mason_bin, executable.mason_path)
  end)
end)
