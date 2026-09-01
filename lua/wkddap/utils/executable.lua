---@module 'wkddap.utils.executable'
--- Executable/Mason binary resolution helpers.
---
--- Thin re-export of `lib.nvim.cross.executable`, which this module's own
--- implementation was upstreamed into (identical PATH/Mason-bin resolution
--- logic).

local cross_executable = require("lib.nvim.cross.executable")

local M = {}

--- Whether an executable exists in PATH. Re-export of
--- `lib.nvim.cross.executable.exists`, which carries the signature -- an
--- `@param` here would describe a parameter list this assignment does not have.
M.exists = cross_executable.exists

--- Absolute path of an executable, or nil. Re-export of
--- `lib.nvim.cross.executable.path`.
M.path = cross_executable.path

--- Path of a Mason-installed binary, or nil. Re-export of
--- `lib.nvim.cross.executable.mason_bin`.
M.mason_path = cross_executable.mason_bin

return M
