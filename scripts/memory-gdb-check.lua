---@module 'scripts.memory-gdb-check'
--- Manual end-to-end check of the memory view (wkddap.memory) against a real
--- GDB over DAP (`gdb -i dap`, GDB 14+), through the real nvim-dap. NOT part of
--- the spec suite (it compiles, spawns gdb and runs a program; the suite's
--- guards forbid all three).
---
---   nvim --headless -u NONE -l scripts/memory-gdb-check.lua [nvim-dap-dir]
---
--- nvim-dap is taken from the argument, else $NVIM_DAP_DIR, else
--- stdpath('data')/lazy/nvim-dap. lib.nvim and ui.nvim are looked up like
--- scripts/test.sh does ($LIB_NVIM_DIR / $UI_NVIM_DIR, ../<name>,
--- stdpath('data')/lazy/<name>). gcc and gdb must be on PATH.
---
--- What it does: compiles scripts/fixtures/memory_target.c with `gcc -g -O0`,
--- sets a breakpoint on its "BREAK HERE" line, launches it under gdb, and at
--- the stop: prints the adapter's memory capabilities as reported, opens the
--- view on `&buffer` (checks the context rows above it, the row alignment and
--- the cursor on buffer[0]), checks the bytes read, writes a byte, checks the
--- re-read and an independent `evaluate`, undoes it, flips a bit and back,
--- reads an unmapped address (error path), jumps to the start of the image
--- (the fixture's `image_start`: the context read fails there and
--- must be retried at offset 0), then writes buffer[1] = 'Z' and continues --
--- the program exits 0 only if that write reached it -- and checks that the
--- view went stale when the session ended.
---
--- With WKDDAP_MEMORY_COMPANION=1 it also opens the view in a REAL companion
--- window (`:Dap memory-window`: a second nvim in the platform's terminal,
--- lib.nvim.companion) before the final write: waits for it to attach, reads
--- its buffer over RPC, presses `n` over there (the client's `send`, as its
--- keymap does) and checks that the page moved here and over there, then
--- closes it. WKDDAP_MEMORY_COMPANION=headless does the same with a headless
--- companion (no window). Unset: no companion, no second process.
---
--- Exit code 0 = every check passed, 1 = a check failed, 2 = setup failed.

local this = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(this)))
local data = vim.fs.normalize(vim.fn.stdpath("data"))

---@param msg string
local function out(msg)
  io.stdout:write(msg, "\n")
end

---@param msg string
local function setup_fail(msg)
  out("SETUP FAILED: " .. msg)
  os.exit(2)
end

---@param name string
---@param env string
---@param marker string
---@param explicit? string
---@return string
local function find_dep(name, env, marker, explicit)
  local places = {
    explicit,
    vim.env[env],
    vim.fs.dirname(root) .. "/" .. name,
    data .. "/lazy/" .. name,
  }
  for _, dir in pairs(places) do
    if dir and dir ~= "" and vim.fn.isdirectory(dir .. "/" .. marker) == 1 then
      return vim.fs.normalize(dir)
    end
  end
  setup_fail(("%s not found (set $%s)"):format(name, env))
  return ""
end

local dap_dir = find_dep("nvim-dap", "NVIM_DAP_DIR", "lua/dap", _G.arg and _G.arg[1] or nil)
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(dap_dir)
vim.opt.rtp:append(find_dep("lib.nvim", "LIB_NVIM_DIR", "lua/lib/nvim"))
vim.opt.rtp:append(find_dep("ui.nvim", "UI_NVIM_DIR", "lua/ui"))
vim.o.swapfile = false
out("nvim-dap: " .. dap_dir)

-- Every notification is printed: the check reports what a user would see.
vim.notify = function(msg, level)
  out(("  notify[%s]: %s"):format(tostring(level), tostring(msg)))
end

local failures = 0
---@param ok boolean
---@param what string
local function check(ok, what)
  out(("%s  %s"):format(ok and "PASS" or "FAIL", what))
  if not ok then
    failures = failures + 1
  end
end

---@param cond fun(): boolean
---@param ms? integer
---@return boolean
local function wait(cond, ms)
  return vim.wait(ms or 15000, function()
    local ok, res = pcall(cond)
    return ok and res == true
  end, 20)
end

-- 1. Build the debuggee ------------------------------------------------------
local src = root .. "/scripts/fixtures/memory_target.c"
local work = vim.fs.normalize(vim.fn.tempname())
vim.fn.mkdir(work, "p")
local exe = work .. "/memory_target" .. (vim.fn.has("win32") == 1 and ".exe" or "")
local cc = vim.system({ "gcc", "-g", "-O0", "-o", exe, src }, { text = true }):wait()
if cc.code ~= 0 then
  setup_fail("gcc: " .. (cc.stderr or ""))
end
local gdb_version = vim.system({ "gdb", "--version" }, { text = true }):wait()
out("gdb: " .. vim.split(gdb_version.stdout or "?", "\n")[1])
out("debuggee: " .. exe)

-- 2. nvim-dap with gdb's built-in DAP server ---------------------------------
local dap = require("dap")
dap.adapters.gdb = { type = "executable", command = "gdb", args = { "-i", "dap" } }

local exit_code = nil
dap.listeners.after.event_exited["memory-gdb-check"] = function(_, body)
  exit_code = body and body.exitCode
end

vim.cmd.edit(vim.fn.fnameescape(src))
local break_line = nil
for lnum, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
  if line:find("BREAK HERE", 1, true) then
    break_line = lnum
  end
end
vim.api.nvim_win_set_cursor(0, { break_line, 0 })
dap.toggle_breakpoint()

dap.run({
  type = "gdb",
  request = "launch",
  name = "memory-gdb-check",
  program = exe,
  cwd = work,
})

if
  not wait(function()
    local s = dap.session()
    return s ~= nil and s.stopped_thread_id ~= nil and s.current_frame ~= nil
  end, 30000)
then
  setup_fail("the debuggee never stopped at the breakpoint")
end
local session = dap.session()
out(
  ("stopped at %s:%s"):format(
    session.current_frame.source and session.current_frame.source.name or "?",
    tostring(session.current_frame.line)
  )
)
check(session.current_frame.line == break_line, "stopped on the BREAK HERE line " .. break_line)

-- 3. Capabilities as reported by gdb -----------------------------------------
local caps = session.capabilities or {}
for _, name in ipairs({
  "supportsReadMemoryRequest",
  "supportsWriteMemoryRequest",
  "supportsMemoryReferences",
  "supportsMemoryEvent",
}) do
  out(("capability %s = %s"):format(name, vim.inspect(caps[name])))
end

---Evaluate `expr` in the stopped frame (synchronously, for the cross-check).
---@param expr string
---@return string|nil
local function evaluate(expr)
  local result, done = nil, false
  session:request(
    "evaluate",
    { expression = expr, frameId = session.current_frame.id, context = "watch" },
    function(err, res)
      result = err and ("error: " .. vim.inspect(err)) or (res and res.result)
      done = true
    end
  )
  wait(function()
    return done
  end)
  return result
end

-- 4. The memory view ---------------------------------------------------------
local memory = require("wkddap.memory")
local format = require("wkddap.memory.format")

---Wait for the view to show `value` at page index `index`, as read back from
---the adapter. The view shows a written byte as soon as the write is sent;
---GDB answers in order, so one more round trip means the write has answered
---(undo entry pushed, re-read sent), and `pending == nil` that the re-read
---has answered too.
---@param index integer
---@param value integer
---@return boolean
local function wait_byte(index, value)
  evaluate("1")
  return wait(function()
    local st = memory.state()
    return st ~= nil and st.pending == nil and st.bytes[index] == value
  end)
end

-- Every readMemory as sent and answered: { offset, ok }, to see the context
-- read and its fallback.
local reads = {}
dap.listeners.after.readMemory["memory-gdb-check"] = function(_, err, _, request)
  reads[#reads + 1] = { offset = request and request.offset, ok = err == nil }
end

---Print buffer lines `first`..`last` (1-based) of the view.
---@param what string
---@param first integer
---@param last integer
local function print_view(what, first, last)
  local bufnr = memory.state().view.surface.bufnr
  out("view (" .. what .. "):")
  for _, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, first - 1, last, false)) do
    out("  | " .. l)
  end
end

---The page index of the byte under the view's cursor.
---@return integer|nil
local function cursor_byte()
  return (require("wkddap.memory.view").cursor_byte(memory.state().view))
end

local rows = require("wkddap.config").get().memory.context_rows
out("memory.context_rows = " .. tostring(rows))
memory.open("&buffer")
check(
  wait(function()
    local st = memory.state()
    return st ~= nil and #st.bytes > 0 and st.pending == nil
  end),
  "readMemory answered for &buffer"
)
local st = memory.state()
if not st then
  setup_fail("the memory view did not open")
  return
end
out(
  ("base memoryReference = %s, page offset = %d, response address = %s, bytes = %d, unreadable = %d"):format(
    st.base,
    st.offset,
    st.address and format.hex_address(st.address) or "nil",
    #st.bytes,
    st.unreadable
  )
)
-- The page starts `rows` rows above buffer (16-byte aligned); buffer[0] is
-- byte `at` of the page.
local at = -st.offset + 1
local addr_of_buffer = format.find_address(evaluate("&buffer"))
check(
  st.offset < 0 and st.offset <= -rows * 16 and st.offset > -(rows + 1) * 16,
  ("the page starts %d bytes (%d rows + alignment) before &buffer"):format(-st.offset, rows)
)
check(st.address == addr_of_buffer + st.offset, "response address = &buffer + offset")
check(st.address % 16 == 0, "the page starts on a 16-byte boundary")
local first = {}
for i = 0, 7 do
  first[#first + 1] = string.char(st.bytes[at + i])
end
check(table.concat(first) == "ABCDEFGH", "bytes at buffer[0..7] are ABCDEFGH")
check(cursor_byte() == at, "cursor on buffer[0] (page byte " .. at .. ")")
print_view("hex, open on &buffer", 1, 4 + rows)

-- Write buffer[1] = 'z' (0x7a), re-read, cross-check with evaluate.
memory.edit(at + 1, 0x7a)
check(wait_byte(at + 1, 0x7a), "writeMemory + re-read shows 0x7a at buffer[1]")
check(
  evaluate("buffer[1]") == "122 'z'",
  "evaluate buffer[1] = " .. tostring(evaluate("buffer[1]"))
)
check(#st.undo == 1, "one undo entry")

memory.undo()
check(wait_byte(at + 1, 0x42), "undo wrote 0x42 back")
check(evaluate("buffer[1]") == "66 'B'", "evaluate buffer[1] = " .. tostring(evaluate("buffer[1]")))
check(#st.undo == 0, "undo stack empty")

-- Bits mode: flip the MSB of buffer[2] ('C' = 0x43 -> 0xc3) and undo it.
memory.toggle_mode()
memory.toggle_bit(at + 2, 0)
check(wait_byte(at + 2, 0xc3), "bit flip (MSB) wrote 0xc3 at buffer[2]")
local bits_row = st.view.render.first_row + math.floor((at - 1) / 4)
print_view("bits, around buffer[0]", bits_row - 1, bits_row + 1)
memory.undo()
check(wait_byte(at + 2, 0x43), "undo of the bit flip wrote 0x43 back")
memory.toggle_mode()

-- Error path: an unmapped address (no context above 0: one read, no retry).
local before = #reads
memory.jump("0x0")
check(
  wait(function()
    return memory.state().error ~= nil and memory.state().pending == nil
  end),
  "readMemory at 0x0 is an error response: " .. tostring(memory.state().error)
)
check(#reads - before == 1 and reads[#reads].offset == 0, "0x0: one read at offset 0, no retry")

-- Fallback: the PE image base (Windows) / the ELF header (Linux) starts a
-- mapping, so the context rows above it are unmapped: the context read fails
-- and is retried at offset 0 instead of showing the error.
-- `image_start` (the fixture) points there; jumping to the pointer reads at
-- its value.
local start_expr = "image_start"
local start_addr = format.find_address(evaluate(start_expr))
out(("%s = %s"):format(start_expr, start_addr and format.hex_address(start_addr) or "?"))
check(start_addr ~= nil, start_expr .. " resolves to an address")
before = #reads
memory.jump(start_expr)
check(
  wait(function()
    local s = memory.state()
    return s.label == start_expr and s.pending == nil and #s.bytes > 0
  end),
  "jump to " .. start_expr .. " shows bytes"
)
local tried = {}
for i = before + 1, #reads do
  tried[#tried + 1] = ("%d:%s"):format(reads[i].offset, reads[i].ok and "ok" or "error")
end
out("readMemory for " .. start_expr .. ": " .. table.concat(tried, ", "))
check(
  #tried == 2
    and not reads[before + 1].ok
    and reads[before + 1].offset < 0
    and reads[before + 2].offset == 0
    and reads[before + 2].ok,
  "context read failed, retried once at offset 0"
)
st = memory.state()
check(
  st.offset == 0 and st.error == nil and st.address == start_addr,
  "page starts at the target, no error"
)
local magic = vim.fn.has("win32") == 1 and { 0x4d, 0x5a } or { 0x7f, 0x45 } -- "MZ" / "\x7fE"
check(st.bytes[1] == magic[1] and st.bytes[2] == magic[2], "first bytes are the image header magic")
check(cursor_byte() == 1, "cursor on the target (page byte 1)")
print_view("hex, fallback on " .. start_expr, 1, 4)

memory.jump("&buffer")
check(wait_byte(at, 0x41), "jump back to &buffer (context rows again)")
check(memory.state().offset == -(at - 1), "same context offset as on open")
check(cursor_byte() == at, "cursor back on buffer[0]")

-- Companion window (opt-in, see the header): the same view in a second nvim.
local companion_mode = vim.env.WKDDAP_MEMORY_COMPANION
if companion_mode and companion_mode ~= "" and companion_mode ~= "0" then
  out("companion window: WKDDAP_MEMORY_COMPANION=" .. companion_mode)
  memory.close()
  memory.open("&buffer", {
    companion = true,
    terminal = companion_mode == "headless" and false or nil,
  })
  check(
    wait(function()
      local s = memory.state()
      return s ~= nil and s.window == "companion" and s.pending == nil and #s.bytes > 0
    end),
    "companion view opened and read &buffer"
  )
  local cst = memory.state()
  if not cst or cst.window ~= "companion" then
    setup_fail("the companion view did not open")
    return
  end
  local h = cst.view.handle
  check(
    wait(function()
      return h:is_attached()
    end, 20000),
    "the companion attached (channel " .. tostring(h.chan) .. ")"
  )

  ---The companion's buffer, read over its channel (it is never blocked in a
  ---request to us here, so a request is safe).
  ---@return string[]|nil
  local function companion_lines()
    if not h.chan then
      return nil
    end
    local ok, res = pcall(
      vim.rpcrequest,
      h.chan,
      "nvim_exec_lua",
      "return vim.api.nvim_buf_get_lines(0, 0, -1, false)",
      {}
    )
    return ok and type(res) == "table" and res or nil
  end
  check(
    wait(function()
      local l = companion_lines()
      return l ~= nil and l[1] ~= nil and l[1]:find("^&buffer  @") ~= nil
    end),
    "the companion shows the page (header: " .. tostring((companion_lines() or {})[1]) .. ")"
  )
  local shown = companion_lines() or {}
  local legend = shown[#shown] or ""
  check(
    legend:find("n/p page", 1, true) ~= nil and legend:find("edit", 1, true) == nil,
    "the companion's legend has navigation only (" .. legend .. ")"
  )
  check(
    shown[rows + 3] ~= nil and shown[rows + 3]:find(" 41 42 43 44 ", 1, true) ~= nil,
    "the companion shows buffer[0..3] on its target row"
  )

  -- `n` pressed in the companion: its keymap calls the client's send().
  local offset_before = cst.offset
  pcall(
    vim.rpcrequest,
    h.chan,
    "nvim_exec_lua",
    "require('lib.nvim.companion.client').send('page', { 1 })",
    {}
  )
  check(
    wait(function()
      local s = memory.state()
      return s ~= nil and s.offset == offset_before + 256 and s.pending == nil
    end),
    "n in the companion paged forward here (offset " .. tostring(memory.state().offset) .. ")"
  )
  local expected = "(+0x" .. format.hex(memory.state().offset) .. ")"
  check(
    wait(function()
      local l = companion_lines()
      return l ~= nil and l[1] ~= nil and l[1]:find(expected, 1, true) ~= nil
    end),
    "the companion shows the new page " .. expected
  )
  if companion_mode ~= "headless" then
    vim.wait(1500, function()
      return false
    end, 50) -- a moment to look at the window
  end
  memory.close()
  check(not h:is_open(), "close() closed the companion handle")
  check(
    wait(function()
      return #require("lib.nvim.companion").handles() == 0
    end),
    "no companion handle left"
  )
  memory.open("&buffer")
  check(wait_byte(at, 0x41), "float reopened on &buffer")
end

-- Final write that the program checks itself.
memory.edit(at + 1, 0x5a) -- 'Z'
check(wait_byte(at + 1, 0x5a), "wrote 'Z' to buffer[1]")
dap.continue()
check(
  wait(function()
    return exit_code ~= nil
  end, 20000),
  "debuggee exited"
)
check(exit_code == 0, "debuggee saw the write (exit code " .. tostring(exit_code) .. ")")
check(
  wait(function()
    return memory.state() ~= nil and memory.state().stale == true
  end),
  "view marked stale after the session ended"
)
memory.edit(1, 0x00)

pcall(dap.terminate)
memory.close()
out(("%s: %d failure(s)"):format(failures == 0 and "ALL PASSED" or "FAILED", failures))
vim.fn.delete(work, "rf")
os.exit(failures == 0 and 0 or 1)
