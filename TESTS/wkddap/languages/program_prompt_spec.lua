--- Covers the "Path to executable" program() prompts in zig.lua, rust.lua,
--- c.lua and assembly.lua: all four were migrated off the blocking
--- vim.fn.input(..., "file") onto lib.nvim.ui.kit.input({completion="file"}),
--- which is callback-based -- nvim-dap resolves these config functions
--- inside coroutine.wrap(), so the migration yields and lets kit.input's
--- on_submit/on_cancel resume the suspended coroutine with the typed value
--- (same idiom already used by lua.lua's host/port prompts).
---
--- kit.input's on_submit never fires synchronously in real usage (it's
--- async: the call just wires up keymaps/autocmds and returns immediately,
--- the callback only fires later once the user actually submits), so these
--- specs mirror that by capturing opts and invoking on_submit/on_cancel only
--- *after* the coroutine has reached its yield point -- calling it inline
--- would try to resume a still-running (not yet suspended) coroutine.

local paths = require("wkddap.utils.paths")

--- Run `program_fn` inside a coroutine (matching how nvim-dap actually
--- resolves a configuration's `program` field) and return the captured
--- kit.input opts plus a getter for the coroutine's eventual result.
---@param program_fn fun(): string
---@return table opts, fun(): any result
local function start(program_fn)
  local result
  local co = coroutine.create(function()
    result = program_fn()
  end)
  coroutine.resume(co)
  -- zig's "Launch (build first)" spawns the build and opens the prompt only
  -- from the completion callback, via vim.schedule -- so the captured opts are
  -- not there the instant resume() returns. The synchronous cases already have
  -- them, so this returns immediately for those.
  vim.wait(500, function()
    return _G.__captured_kit_input_opts ~= nil
  end, 1)
  local opts = _G.__captured_kit_input_opts
  _G.__captured_kit_input_opts = nil
  return opts, function()
    return result
  end
end

describe('wkddap.languages program() prompts (kit.input completion="file")', function()
  before_each(function()
    package.loaded["dap"] = { configurations = {} }
    package.loaded["lib.nvim.ui.kit"] = {
      input = function(opts)
        _G.__captured_kit_input_opts = opts
      end,
    }
  end)

  after_each(function()
    package.loaded["dap"] = nil
    package.loaded["lib.nvim.ui.kit"] = nil
    _G.__captured_kit_input_opts = nil
  end)

  local function reload(mod)
    package.loaded["wkddap.languages." .. mod] = nil
    return require("wkddap.languages." .. mod)
  end

  -- { module, dap config-table key, index of the "Launch" entry to test }
  local cases = {
    { mod = "rust", key = "rust", idx = 1 },
    { mod = "c", key = "c", idx = 1 },
    { mod = "assembly", key = "asm", idx = 1 },
    { mod = "zig", key = "zig", idx = 1 },
    { mod = "zig", key = "zig", idx = 2 }, -- "Launch (build first)"
    { mod = "csharp", key = "cs", idx = 1 }, -- "Path to DLL"
  }

  for _, case in ipairs(cases) do
    it(
      ('%s configurations.%s[%d].program: completion="file" + submit -> normalized path'):format(
        case.mod,
        case.key,
        case.idx
      ),
      function()
        local lang = reload(case.mod)
        lang.load()
        local program = package.loaded["dap"].configurations[case.key][case.idx].program

        -- "Launch (build first)" (zig idx 2) shells out to `zig build` from
        -- inside program() itself, so the stub must still be in place when
        -- start() actually invokes it below -- load() only builds the config
        -- table, it never calls program().
        local orig_system = vim.system
        -- Both call shapes: `vim.system(cmd, opts):wait()` (what the older
        -- configs used) and `vim.system(cmd, opts, on_exit)` (what zig's
        -- "Launch (build first)" uses now, so the build does not block the
        -- editor). The callback has to actually fire, or the prompt it guards
        -- is never reached.
        -- Stands in for both call shapes, so it takes the callback the real
        -- two-argument overload does not, and returns only the fields the
        -- code under test reads.
        ---@diagnostic disable-next-line: redundant-parameter, missing-fields
        vim.system = function(_cmd, _opts, on_exit)
          if type(on_exit) == "function" then
            on_exit({ code = 0, signal = 0, stdout = "", stderr = "" })
          end
          return {
            wait = function()
              return { code = 0, stdout = "", stderr = "" }
            end,
          }
        end
        local opts, result = start(program)
        vim.system = orig_system

        assert.is_not_nil(opts, "kit.input was called")
        assert.are.equal("file", opts.completion, 'prompted with completion = "file"')

        opts.on_submit("/tmp/foo/bar")
        assert.are.equal(paths.normalize("/tmp/foo/bar"), result(), "submitted path is normalized")
      end
    )

    it(
      ("%s configurations.%s[%d].program: <Esc> resolves like the old empty-string cancel"):format(
        case.mod,
        case.key,
        case.idx
      ),
      function()
        local lang = reload(case.mod)
        lang.load()
        local program = package.loaded["dap"].configurations[case.key][case.idx].program

        local orig_system = vim.system
        -- Both call shapes: `vim.system(cmd, opts):wait()` (what the older
        -- configs used) and `vim.system(cmd, opts, on_exit)` (what zig's
        -- "Launch (build first)" uses now, so the build does not block the
        -- editor). The callback has to actually fire, or the prompt it guards
        -- is never reached.
        vim.system = function(_cmd, _opts, on_exit)
          if type(on_exit) == "function" then
            on_exit({ code = 0, signal = 0, stdout = "", stderr = "" })
          end
          return {
            wait = function()
              return { code = 0, stdout = "", stderr = "" }
            end,
          }
        end
        local opts, result = start(program)
        vim.system = orig_system

        opts.on_cancel()
        assert.are.equal(
          paths.normalize(""),
          result(),
          'cancel resolves the same as vim.fn.input\'s old Esc -> ""'
        )
      end
    )
  end
end)
