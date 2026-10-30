--- Covers wkddap.memory (the memory view controller) together with its real
--- float (wkddap.memory.view on ui.kit.surface), driven by a fake nvim-dap
--- session that answers readMemory / writeMemory / evaluate the way GDB's DAP
--- server does (base64 data, hex `address`, `unreadableBytes`, error bodies).
---
--- nvim-dap itself is never loaded: `package.loaded["dap"]` is a stand-in
--- (TESTS/README.md), as are wkddap.utils.notify (to read the messages) and
--- ui.kit's `input` (to answer the prompts).

local format = require("wkddap.memory.format")

local BASE = 0x404010

---A debug-adapter double over a byte table. `readable` bounds what can be
---read (everything else becomes `unreadableBytes`), `fail_read` turns every
---readMemory into an error response, `fail_below` (an address) every
---readMemory that starts below it (GDB fails a whole read whose start is
---unmapped), `empty_read` answers it with no body.
---
---It answers synchronously unless `deferred` is set: then every request is
---recorded when sent but answered (memory read or written, callback run)
---only by `flush()`, in the order sent -- the way a real adapter answers
---later, while the user keeps pressing keys.
---@param caps? table
local function fake_session(caps)
  local s = {
    capabilities = caps or { supportsReadMemoryRequest = true, supportsWriteMemoryRequest = true },
    config = { type = "gdb" },
    current_frame = { id = 7 },
    mem = {},
    readable = { lo = BASE - 4096, hi = BASE + 4096 },
    requests = {},
    deferred = false,
    queue = {},
    expressions = {
      ["&buffer"] = { result = "(char (*)[32]) 0x404010 <buffer>", memoryReference = "0x404010" },
      ["ptr"] = { result = '(char *) 0x404020 "QRS"' },
      -- lldb-dap: a pointer's value, with a memoryReference of where the
      -- pointer itself is stored.
      ["image_start"] = { result = "0x0000000000404030", memoryReference = "0x404050" },
      -- codelldb: a pointer to characters shown as the string, no
      -- memoryReference; the `,x` format specifier gives the address.
      ["&cbuf"] = { result = '"ABCDEFGH"', type = "unsigned char (*)[32]" },
      ["&cbuf,x"] = { result = "0x0000000000404010", type = "unsigned char (*)[32]" },
      ["n"] = { result = "42" },
      ["nptr"] = { result = '"42"', type = "char *" },
    },
  }
  for i = 0, 511 do
    s.mem[BASE + i] = (0x41 + i) % 256
  end

  local answer

  function s:request(command, args, cb)
    table.insert(self.requests, { command = command, args = vim.deepcopy(args) })
    if self.deferred then
      args = vim.deepcopy(args)
      table.insert(self.queue, function()
        answer(self, command, args, cb)
      end)
      return
    end
    answer(self, command, args, cb)
  end

  ---Answer the queued requests (and those the answers send), oldest first:
  ---all of them, or only the next `n`.
  ---@param n? integer
  function s:flush(n)
    while #self.queue > 0 and (n == nil or n > 0) do
      table.remove(self.queue, 1)()
      n = n and n - 1
    end
  end

  answer = function(self, command, args, cb)
    if command == "evaluate" then
      local hit = self.expressions[args.expression]
      if not hit then
        cb({ message = 'No symbol "' .. args.expression .. '" in current context.' }, nil)
      else
        cb(nil, hit)
      end
    elseif command == "readMemory" then
      if self.fail_read then
        cb({
          message = "error",
          body = { error = { format = "Cannot access memory at address 0x0" } },
        }, nil)
        return
      end
      if self.empty_read then
        cb(nil, nil)
        return
      end
      local addr = format.parse_address(args.memoryReference) + (args.offset or 0)
      if self.fail_below and addr < self.fail_below then
        cb({
          message = "error",
          body = {
            error = { format = "Cannot access memory at address " .. format.hex_address(addr) },
          },
        }, nil)
        return
      end
      local data = {}
      for i = 0, args.count - 1 do
        local a = addr + i
        if a < self.readable.lo or a >= self.readable.hi then
          break
        end
        -- codelldb reads one region only: a read that starts below `cut_at`
        -- stops there, although the memory beyond is readable.
        if self.cut_at and addr < self.cut_at and a >= self.cut_at then
          break
        end
        data[#data + 1] = self.mem[a] or 0
      end
      cb(nil, {
        address = format.hex_address(addr),
        data = format.encode(data),
        unreadableBytes = args.count - #data,
      })
    elseif command == "writeMemory" then
      local addr = format.parse_address(args.memoryReference) + (args.offset or 0)
      for i, b in ipairs(format.decode(args.data)) do
        self.mem[addr + i - 1] = b
      end
      cb(nil, nil) -- GDB answers with an empty body
    end
  end

  ---@param command string
  ---@return table[]
  function s:sent(command)
    return vim.tbl_filter(function(r)
      return r.command == command
    end, self.requests)
  end

  return s
end

describe("wkddap.memory", function()
  local memory, session, messages, prompts, listeners

  local function lines()
    local state = memory.state()
    return vim.api.nvim_buf_get_lines(state.view.surface.bufnr, 0, -1, false)
  end

  local function message_matching(pattern)
    for _, m in ipairs(messages) do
      if m.msg:find(pattern, 1, true) then
        return m
      end
    end
    return nil
  end

  before_each(function()
    messages, prompts = {}, {}
    session = fake_session()
    listeners = { after = {}, before = {} }
    package.loaded["dap"] = {
      session = function()
        return session
      end,
      listeners = listeners,
    }
    package.loaded["wkddap.utils.notify"] = {
      info = function(msg)
        table.insert(messages, { level = "info", msg = msg })
      end,
      warn = function(msg)
        table.insert(messages, { level = "warn", msg = msg })
      end,
      error = function(msg)
        table.insert(messages, { level = "error", msg = msg })
      end,
    }
    package.loaded["ui.kit"] = {
      input = function(opts)
        table.insert(prompts, opts)
      end,
    }
    package.loaded["wkddap.memory"] = nil
    memory = require("wkddap.memory")
    -- The target as the first row: most specs here are about reading,
    -- paging and editing, not about the context rows ("context rows" below).
    require("wkddap.config").setup({ memory = { context_rows = 0 } })
  end)

  after_each(function()
    require("wkddap.config").setup({})
    memory.close()
    package.loaded["dap"] = nil
    package.loaded["wkddap.utils.notify"] = nil
    package.loaded["ui.kit"] = nil
    package.loaded["wkddap.memory"] = nil
  end)

  describe("session checks", function()
    it("says so when nvim-dap is not installed", function()
      package.loaded["dap"] = nil
      memory.open("0x404010")
      assert.is_not_nil(message_matching("nvim-dap is not installed"))
      assert.is_nil(memory.state())
    end)

    it("says so when no session is running", function()
      session = nil
      memory.open("0x404010")
      assert.is_not_nil(message_matching("no debug session is running"))
      assert.is_nil(memory.state())
    end)

    it("says so when the adapter lacks supportsReadMemoryRequest, and sends nothing", function()
      session = fake_session({ supportsWriteMemoryRequest = true })
      memory.open("0x404010")
      local m = message_matching("supportsReadMemoryRequest")
      assert.is_not_nil(m)
      assert.are.equal("warn", m.level)
      assert.truthy(m.msg:find("'gdb'", 1, true))
      assert.are.equal(0, #session.requests)
      assert.is_nil(memory.state())
    end)
  end)

  describe("opening", function()
    it("reads one page at a literal address and renders hex + ASCII", function()
      memory.open("0x404010")
      local reads = session:sent("readMemory")
      assert.are.equal(1, #reads)
      assert.are.same(
        { memoryReference = "0x404010", offset = 0, count = format.PAGE_SIZE },
        reads[1].args
      )
      assert.are.same({}, session:sent("evaluate"))

      local buf = lines()
      assert.are.equal("0x404010  @ 0x404010  (+0x0)  [hex]", buf[1])
      assert.are.equal(
        "0x00404010  41 42 43 44 45 46 47 48  49 4a 4b 4c 4d 4e 4f 50  |ABCDEFGHIJKLMNOP|",
        buf[3]
      )
      assert.are.equal(2 + 16 + 2, #buf) -- header, ruler, 16 rows, blank, legend
      assert.are.equal("wkddap-memory", vim.bo[memory.state().view.surface.bufnr].filetype)
    end)

    it("resolves an expression through evaluate and its memoryReference", function()
      memory.open("&buffer")
      local evals = session:sent("evaluate")
      assert.are.equal(1, #evals)
      assert.are.same({ expression = "&buffer", frameId = 7, context = "watch" }, evals[1].args)
      assert.are.equal("0x404010", session:sent("readMemory")[1].args.memoryReference)
      assert.truthy(lines()[1]:find("^&buffer  @ 0x404010"))
    end)

    it("falls back to the first 0x... of the evaluate result", function()
      memory.open("ptr")
      assert.are.equal("0x404020", session:sent("readMemory")[1].args.memoryReference)
    end)

    it("takes a value that is an address over the memoryReference (lldb-dap pointer)", function()
      memory.open("image_start")
      assert.are.equal("0x0000000000404030", session:sent("readMemory")[1].args.memoryReference)
    end)

    it("asks codelldb for a pointer shown as a string again with ,x", function()
      memory.open("&cbuf")
      local evals = session:sent("evaluate")
      assert.are.equal(2, #evals)
      assert.are.equal("&cbuf,x", evals[2].args.expression)
      assert.are.equal("0x0000000000404010", session:sent("readMemory")[1].args.memoryReference)
      assert.truthy(lines()[1]:find("^&cbuf  @ 0x404010"))
    end)

    it("refuses a pointer whose ,x form is no address either", function()
      memory.open("nptr")
      assert.are.equal(2, #session:sent("evaluate"))
      assert.is_not_nil(message_matching("is not an address"))
      assert.is_nil(memory.state())
    end)

    it("sends a 64-bit literal unrounded and shows offsets instead of an address", function()
      memory.open("0xb4000078a1c3e011") -- an ARM64 tagged pointer, above 2^53
      assert.are.equal("0xb4000078a1c3e011", session:sent("readMemory")[1].args.memoryReference)
      memory.state().bytes[1] = 0 -- pretend it was readable
      memory.edit(1, 0x01)
      assert.are.equal("0xb4000078a1c3e011", session:sent("writeMemory")[1].args.memoryReference)
      assert.truthy(lines()[1]:find("@ ?", 1, true))
    end)

    it("sends a decimal literal as exact hex", function()
      memory.open("18446744073709551615")
      assert.are.equal("0xffffffffffffffff", session:sent("readMemory")[1].args.memoryReference)
    end)

    it("takes a 64-bit address from an evaluate result unrounded", function()
      session.expressions["tp"] = { result = "(int *) 0xb4000078a1c3e011" }
      memory.open("tp")
      assert.are.equal("0xb4000078a1c3e011", session:sent("readMemory")[1].args.memoryReference)
    end)

    it("refuses a value that is not an address, with a hint", function()
      memory.open("n")
      local m = message_matching("is not an address")
      assert.is_not_nil(m)
      assert.truthy(m.msg:find("try &n", 1, true))
      assert.is_nil(memory.state())
    end)

    it("reports an evaluate error response", function()
      memory.open("nosuch")
      assert.is_not_nil(message_matching("No symbol"))
      assert.is_nil(memory.state())
    end)

    it("prompts when no target is given, and opens on submit", function()
      memory.open()
      assert.are.equal(1, #prompts)
      assert.truthy(prompts[1].title:find("address or expression"))
      prompts[1].on_submit("0x404010")
      assert.is_not_nil(memory.state())
      assert.are.equal(1, #session:sent("readMemory"))
    end)
  end)

  describe("read failures", function()
    it("shows a readMemory error response instead of rows", function()
      session.fail_read = true
      memory.open("0x404010")
      assert.is_not_nil(message_matching("readMemory failed: Cannot access memory"))
      assert.are.equal("readMemory failed: Cannot access memory at address 0x0", lines()[3])
    end)

    it("renders unreadableBytes as ?? and refuses to edit them", function()
      session.readable.hi = BASE + 8
      memory.open("0x404010")
      local buf = lines()
      assert.truthy(buf[1]:find("248 unreadable", 1, true))
      assert.are.equal(
        "0x00404010  41 42 43 44 45 46 47 48  ?? ?? ?? ?? ?? ?? ?? ??  |ABCDEFGH........|",
        buf[3]
      )
      memory.edit(9, 0x00)
      assert.is_not_nil(message_matching("unreadable and cannot be edited"))
      assert.are.same({}, session:sent("writeMemory"))
    end)
  end)

  describe("navigation", function()
    it("toggles to bits (MSB first) and back", function()
      memory.open("0x404010")
      memory.toggle_mode()
      local buf = lines()
      assert.truthy(buf[1]:find("[bits]", 1, true))
      assert.are.equal("0x00404010  01000001 01000010 01000011 01000100  |ABCD|", buf[3])
      memory.toggle_mode()
      assert.truthy(lines()[1]:find("[hex]", 1, true))
    end)

    it("pages forward and back by offset from the same base", function()
      memory.open("0x404010")
      memory.page(1)
      memory.page(-1)
      memory.page(-1)
      local reads = session:sent("readMemory")
      assert.are.equal(4, #reads)
      assert.are.same({ 0, 256, 0, -256 }, {
        reads[1].args.offset,
        reads[2].args.offset,
        reads[3].args.offset,
        reads[4].args.offset,
      })
      for _, r in ipairs(reads) do
        assert.are.equal("0x404010", r.args.memoryReference)
      end
      assert.truthy(lines()[3]:find("^0x00403f10"))
    end)

    it("does not page below address 0 (and survives a read without a body)", function()
      session.empty_read = true -- no `address` to show: falls back to base + offset
      memory.open("0x10")
      memory.page(-1)
      assert.is_not_nil(message_matching("no page below address 0"))
      assert.are.equal(1, #session:sent("readMemory"))
      assert.truthy(lines()[1]:find("^0x10  @ 0x10 "))
    end)

    it("jumps to another target in the same window", function()
      memory.open("0x404010")
      local winid = memory.state().view.surface.winid
      memory.jump("&buffer")
      assert.are.equal(winid, memory.state().view.surface.winid)
      assert.are.equal("&buffer", memory.state().label)
      memory.jump()
      assert.are.equal("&buffer", prompts[#prompts].default)
    end)

    it("refresh re-reads the page", function()
      memory.open("0x404010")
      session.mem[BASE] = 0x00
      memory.refresh()
      assert.are.equal(2, #session:sent("readMemory"))
      assert.truthy(lines()[3]:find("^0x00404010  00 42"))
    end)
  end)

  describe("editing", function()
    it("writes one byte as base64, then re-reads the page", function()
      memory.open("0x404010")
      memory.edit(2, 0x5a)
      local writes = session:sent("writeMemory")
      assert.are.equal(1, #writes)
      assert.are.same({ memoryReference = "0x404010", offset = 1, data = "Wg==" }, writes[1].args)
      assert.are.equal(0x5a, session.mem[BASE + 1])
      assert.are.equal(2, #session:sent("readMemory"))
      assert.truthy(lines()[3]:find("^0x00404010  41 5a 43", 1, false))
      assert.are.equal(1, #memory.state().undo)
    end)

    it("edits through the prompt, pre-filled with the current value", function()
      memory.open("0x404010")
      memory.edit(3)
      local p = prompts[#prompts]
      assert.are.equal("43", p.default)
      assert.truthy(p.title:find("0x404012", 1, true))
      p.on_submit("ff")
      assert.are.equal(0xff, session.mem[BASE + 2])
    end)

    it("rejects a value that is not a byte", function()
      memory.open("0x404010")
      memory.edit(1)
      prompts[#prompts].on_submit("xyz")
      assert.is_not_nil(message_matching("not a byte value"))
      assert.are.same({}, session:sent("writeMemory"))
    end)

    it("flips one bit in bits mode (0 = MSB)", function()
      memory.open("0x404010")
      memory.toggle_bit(1, 0)
      assert.is_not_nil(message_matching("switch to bits mode"))
      memory.toggle_mode()
      memory.toggle_bit(1, 0)
      assert.are.equal(0xc1, session.mem[BASE])
      memory.click(1, 7) -- double-click on a bit
      assert.are.equal(0xc0, session.mem[BASE])
    end)

    it("undo writes the previous value back, newest first", function()
      memory.open("0x404010")
      memory.edit(1, 0x00)
      memory.edit(1, 0x11)
      memory.undo()
      assert.are.equal(0x00, session.mem[BASE])
      memory.undo()
      assert.are.equal(0x41, session.mem[BASE])
      local writes = session:sent("writeMemory")
      assert.are.equal("AA==", writes[3].args.data)
      assert.are.equal("QQ==", writes[4].args.data)
      assert.truthy(lines()[3]:find("^0x00404010  41 42"))
      memory.undo()
      assert.is_not_nil(message_matching("nothing to undo"))
      assert.are.equal(4, #session:sent("writeMemory"))
    end)

    it("undo still targets the original location after paging away", function()
      memory.open("0x404010")
      memory.edit(5, 0x00)
      memory.page(1)
      memory.undo()
      local w = session:sent("writeMemory")[2]
      assert.are.same({ memoryReference = "0x404010", offset = 4, data = "RQ==" }, w.args)
    end)

    it("says so when the adapter lacks supportsWriteMemoryRequest", function()
      session = fake_session({ supportsReadMemoryRequest = true })
      memory.open("0x404010")
      memory.edit(1, 0x00)
      assert.is_not_nil(message_matching("supportsWriteMemoryRequest"))
      assert.are.same({}, session:sent("writeMemory"))
    end)

    it("reports a writeMemory error response and keeps nothing to undo", function()
      memory.open("0x404010")
      local original = session.request
      session.request = function(self, command, args, cb)
        if command == "writeMemory" then
          table.insert(self.requests, { command = command, args = args })
          cb({ message = "Cannot access memory at address 0x404010" }, nil)
          return
        end
        return original(self, command, args, cb)
      end
      memory.edit(1, 0x00)
      assert.is_not_nil(message_matching("writeMemory failed: Cannot access memory"))
      assert.are.equal(0, #memory.state().undo)
    end)
  end)

  describe("requests answered later", function()
    before_each(function()
      session.mem[BASE] = 0x11 -- page 0, byte 1
      session.mem[BASE + 256] = 0x80 -- page 1, byte 1
      session.mem[BASE + 257] = 0x80 -- page 1, byte 2
      session.deferred = true
    end)

    it("shows the next page only when its read answers", function()
      memory.open("0x404010")
      session:flush()
      memory.page(1)
      memory.page(1) -- `nn` before the first read answers: two pages on
      assert.are.equal(0, memory.state().offset)
      assert.truthy(lines()[3]:find("^0x00404010  11 "))
      session:flush()
      local reads = session:sent("readMemory")
      assert.are.same({ 256, 512 }, { reads[2].args.offset, reads[3].args.offset })
      assert.are.equal(512, memory.state().offset)
      assert.truthy(lines()[3]:find("^0x00404210 "))
    end)

    it("refuses an edit while another page is being read", function()
      memory.open("0x404010")
      session:flush()
      memory.toggle_mode()
      memory.page(1)
      memory.toggle_bit(1, 0) -- `n<Space>`: the page on screen is still page 0
      memory.edit(1, 0x00)
      assert.are.same({}, session:sent("writeMemory"))
      assert.is_not_nil(message_matching("still being read"))
      session:flush()
      assert.are.equal(0x11, session.mem[BASE])
      assert.are.equal(0x80, session.mem[BASE + 256])

      memory.toggle_bit(1, 0) -- now on page 1
      session:flush()
      assert.are.equal(0x00, session.mem[BASE + 256])
      assert.are.same(
        { ref = "0x404010", offset = 256, old = 0x80, new = 0x00 },
        memory.state().undo[1]
      )
    end)

    it("refuses an edit while a jump in the same view is being read", function()
      memory.open("0x404010")
      session:flush()
      memory.jump("0x404110")
      memory.edit(1, 0x00)
      assert.are.same({}, session:sent("writeMemory"))
      session:flush()
      assert.are.equal("0x404110", memory.state().label)
      memory.edit(1, 0x01)
      session:flush()
      assert.are.equal(0x01, session.mem[BASE + 256])
      assert.are.equal(0x11, session.mem[BASE])
    end)

    it("builds a second edit of a byte on the first, before either answers", function()
      memory.open("0x404110")
      session:flush()
      memory.toggle_mode()
      memory.toggle_bit(2, 0) -- 0x80 -> 0x00
      memory.toggle_bit(2, 1) -- 0x00 -> 0x40
      assert.truthy(lines()[3]:find(" 01000000 ", 1, true)) -- shown at once
      session:flush()
      assert.are.equal(0x40, session.mem[BASE + 257])
      local undo = memory.state().undo
      assert.are.same({ 0x80, 0x00 }, { undo[1].old, undo[2].old })
      memory.undo()
      memory.undo()
      session:flush()
      assert.are.equal(0x80, session.mem[BASE + 257])
    end)

    it("drops a read sent before a write, so the old byte does not come back", function()
      memory.open("0x404110")
      session:flush()
      memory.refresh() -- e.g. event_stopped: read pending
      memory.edit(1, 0x22)
      session:flush(1) -- the read answers with the byte from before the write
      assert.are.equal(0x22, memory.state().bytes[1])
      memory.edit(1, 0x33) -- builds on 0x22, not on the 0x80 that read saw
      session:flush()
      assert.are.equal(0x33, memory.state().bytes[1])
      assert.are.same({ 0x80, 0x22 }, { memory.state().undo[1].old, memory.state().undo[2].old })
      assert.truthy(lines()[3]:find("^0x00404110  33 "))
    end)
  end)

  describe("session lifetime", function()
    it("marks the view stale when the session terminates, and refuses reads", function()
      memory.open("0x404010")
      listeners.after.event_terminated["wkddap.memory"](fake_session(), {}) -- another session
      assert.is_false(memory.state().stale)

      listeners.after.event_terminated["wkddap.memory"](session, {})
      assert.is_true(memory.state().stale)
      assert.truthy(lines()[1]:find("[stale: session ended]", 1, true))
      local cfg = vim.api.nvim_win_get_config(memory.state().view.surface.winid)
      assert.truthy(vim.inspect(cfg.title):find("stale", 1, true))

      memory.refresh()
      memory.edit(1, 0)
      assert.is_not_nil(message_matching("session has ended"))
      assert.are.equal(1, #session:sent("readMemory"))
      assert.are.same({}, session:sent("writeMemory"))
    end)

    it("registers exited and disconnect too", function()
      memory.open("0x404010")
      assert.is_function(listeners.after.event_exited["wkddap.memory"])
      listeners.after.disconnect["wkddap.memory"](session, {})
      assert.is_true(memory.state().stale)
    end)

    it("goes stale when nvim-dap closed the session without an event", function()
      memory.open("0x404010")
      session.closed = true -- adapter died / pipe closed / disconnect timed out
      memory.refresh()
      memory.page(1)
      memory.edit(1, 0)
      assert.is_true(memory.state().stale)
      assert.is_not_nil(message_matching("session has ended"))
      assert.truthy(lines()[1]:find("[stale: session ended]", 1, true))
      assert.are.equal(1, #session:sent("readMemory"))
      assert.are.same({}, session:sent("writeMemory"))
    end)

    it("re-reads when the debuggee stops again", function()
      memory.open("0x404010")
      listeners.after.event_stopped["wkddap.memory"](session, {})
      listeners.after.event_memory["wkddap.memory"](session, {})
      assert.are.equal(3, #session:sent("readMemory"))
    end)

    it("removes its listeners when the view closes", function()
      memory.open("0x404010")
      local winid = memory.state().view.surface.winid
      vim.api.nvim_win_close(winid, true)
      assert.is_nil(memory.state())
      for _, event in ipairs({ "event_terminated", "event_exited", "disconnect", "event_stopped" }) do
        assert.is_nil(listeners.after[event]["wkddap.memory"], event)
      end
    end)
  end)

  describe("context rows", function()
    local view_mod = require("wkddap.memory.view")

    before_each(function()
      require("wkddap.config").setup({}) -- the default: 4 rows above the target
    end)

    local function cursor_byte()
      return (view_mod.cursor_byte(memory.state().view))
    end

    ---The target highlights of the buffer as { line (0-based), col } pairs.
    local function target_marks()
      local ns = vim.api.nvim_create_namespace("wkddap_memory")
      local bufnr = memory.state().view.surface.bufnr
      local found = {}
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })) do
        if m[4].hl_group == format.TARGET_GROUP then
          found[#found + 1] = { m[2], m[3] }
        end
      end
      return found
    end

    it("opens 4 aligned rows above the target, cursor on the target byte", function()
      memory.open("0x404010")
      local reads = session:sent("readMemory")
      assert.are.equal(1, #reads)
      assert.are.same(
        { memoryReference = "0x404010", offset = -64, count = format.PAGE_SIZE },
        reads[1].args
      )
      assert.are.equal(-64, memory.state().offset)
      local buf = lines()
      assert.are.equal("0x404010  @ 0x403fd0  (-0x40)  [hex]", buf[1])
      assert.truthy(buf[3]:find("^0x00403fd0  00 00 "))
      assert.are.equal(
        "0x00404010  41 42 43 44 45 46 47 48  49 4a 4b 4c 4d 4e 4f 50  |ABCDEFGHIJKLMNOP|",
        buf[7]
      )
      assert.are.equal(65, cursor_byte())
      assert.are.same(
        { 7, memory.state().view.render.layout.cells[1] },
        vim.api.nvim_win_get_cursor(0)
      )
    end)

    it("aligns the first row to 16 bytes for an unaligned target", function()
      memory.open("0x404013")
      local offset = session:sent("readMemory")[1].args.offset
      assert.are.equal(0x403fd0 - 0x404013, offset)
      assert.are.equal(68, cursor_byte())
      assert.truthy(lines()[7]:find("^0x00404010 "))
      local layout = memory.state().view.render.layout
      -- The cell and its ASCII character, on row 5 (0-based line 6).
      assert.are.same({ { 6, layout.cells[4] }, { 6, layout.ascii_start + 3 } }, target_marks())
    end)

    it("is the context_offset of format for every target", function()
      for _, addr in ipairs({ 0x404010, 0x40401f, 0x10, 0x3f, 0x0 }) do
        memory.close()
        session.requests = {}
        memory.open(format.hex_address(addr))
        local sent = session:sent("readMemory")[1].args.offset
        assert.are.equal(format.context_offset(addr, 4), sent, format.hex_address(addr))
      end
    end)

    it("clamps at address 0, and p still stops there", function()
      session.readable.lo = 0
      memory.open("0x20")
      assert.are.equal(-32, session:sent("readMemory")[1].args.offset)
      assert.are.equal(33, cursor_byte())
      assert.truthy(lines()[1]:find("^0x20  @ 0x0 "))
      memory.page(-1)
      assert.is_not_nil(message_matching("no page below address 0"))
      assert.are.equal(1, #session:sent("readMemory"))
    end)

    it("reads exactly 64 bytes before a target whose address is not known", function()
      session.readable = { lo = 0, hi = math.huge } -- else the read has no byte and is retried
      memory.open("0xb4000078a1c3e011") -- above 2^53: kept as an opaque reference
      assert.are.equal(-64, session:sent("readMemory")[1].args.offset)
      assert.are.equal(65, cursor_byte())
      assert.truthy(lines()[1]:find("@ ?  (-0x40)", 1, true))
      assert.truthy(lines()[7]:find("^ +%+0x0  "))
    end)

    it("context_rows = 0 opens on the target as the first row", function()
      require("wkddap.config").setup({ memory = { context_rows = 0 } })
      memory.open("0x404013")
      assert.are.equal(0, session:sent("readMemory")[1].args.offset)
      assert.are.equal(1, cursor_byte())
    end)

    it("retries at offset 0 when the context read fails, without an error", function()
      session.fail_below = BASE -- nothing mapped below the target
      memory.open("0x404010")
      local reads = session:sent("readMemory")
      assert.are.same({ -64, 0 }, { reads[1].args.offset, reads[2].args.offset })
      local state = memory.state()
      assert.are.equal(0, state.offset)
      assert.is_nil(state.error)
      assert.is_nil(message_matching("readMemory failed"))
      assert.truthy(lines()[3]:find("^0x00404010  41 42 "))
      assert.are.equal(1, cursor_byte())
    end)

    it("retries at offset 0 when the context read succeeds with no byte (codelldb)", function()
      session.readable.lo = BASE -- the start is unreadable: no data, all unreadableBytes
      memory.open("0x404010")
      local reads = session:sent("readMemory")
      assert.are.same({ -64, 0 }, { reads[1].args.offset, reads[2].args.offset })
      local state = memory.state()
      assert.are.equal(0, state.offset)
      assert.are.equal(0, state.unreadable)
      assert.truthy(lines()[3]:find("^0x00404010  41 42 "))
      assert.are.equal(1, cursor_byte())
      memory.edit(1, 0x00)
      assert.are.equal(0x00, session.mem[BASE])
    end)

    it("reads again from where a context read stopped at a region boundary (codelldb)", function()
      session.cut_at = BASE - 32 -- 32 context bytes, then "unreadable" although it is not
      memory.open("0x404010")
      local reads = session:sent("readMemory")
      assert.are.same({ -64, -32 }, { reads[1].args.offset, reads[2].args.offset })
      local state = memory.state()
      assert.are.equal(-32, state.offset)
      assert.are.equal(256, #state.bytes)
      assert.are.equal(0, state.unreadable)
      assert.truthy(lines()[3]:find("^0x00403ff0  "))
      assert.are.equal(33, cursor_byte())
    end)

    it("rounds the second read up to a row", function()
      session.cut_at = BASE - 40 -- 24 context bytes: the row below is -32
      memory.open("0x404010")
      local reads = session:sent("readMemory")
      assert.are.same({ -64, -32 }, { reads[1].args.offset, reads[2].args.offset })
      assert.are.equal(-32, memory.state().offset)
    end)

    it("keeps the context rows when the target itself is unreadable", function()
      session.readable.hi = BASE -- context readable, the target is not
      memory.open("0x404010")
      local reads = session:sent("readMemory")
      assert.are.same({ -64, 0 }, { reads[1].args.offset, reads[2].args.offset })
      local state = memory.state()
      assert.are.equal(-64, state.offset)
      assert.are.equal(64, #state.bytes)
      assert.are.equal(192, state.unreadable)
      assert.are.equal(65, cursor_byte())
      assert.truthy(lines()[3 + 4]:find("0x00404010  ?? ", 1, true))
    end)

    it("shows the error when the retry at offset 0 fails too, and retries only once", function()
      session.fail_read = true
      memory.open("0x404010")
      assert.are.equal(2, #session:sent("readMemory"))
      assert.are.equal("readMemory failed: Cannot access memory at address 0x0", lines()[3])
      assert.is_not_nil(message_matching("readMemory failed"))
      memory.refresh() -- a plain re-read is no context read: no retry
      assert.are.equal(3, #session:sent("readMemory"))
    end)

    it("a failing page or refresh is not retried", function()
      memory.open("0x404010")
      session.fail_read = true
      memory.page(-1)
      assert.are.equal(2, #session:sent("readMemory"))
      assert.is_not_nil(memory.state().error)
    end)

    it("jumps with context rows in the reused view, cursor on the new target", function()
      memory.open("0x404010")
      vim.api.nvim_win_set_cursor(0, { 3, memory.state().view.render.layout.cells[2] })
      memory.jump("0x404110")
      assert.are.equal(-64, session:sent("readMemory")[2].args.offset)
      assert.are.equal("0x404110", memory.state().label)
      assert.are.equal(65, cursor_byte())
    end)

    it("moves the cursor to the target only when that read answers", function()
      session.deferred = true
      memory.open("0x404010")
      assert.are.equal(65, cursor_byte()) -- already on the (empty) target cell
      session:flush()
      assert.are.equal(65, cursor_byte())
      vim.api.nvim_win_set_cursor(0, { 4, memory.state().view.render.layout.cells[3] })
      memory.jump("0x404110")
      assert.are.equal(19, cursor_byte()) -- the old page, cursor untouched
      session:flush()
      assert.are.equal(65, cursor_byte())
      assert.are.equal("0x404110", memory.state().label)
    end)

    it("keeps the fallback and the focus through a refresh while the open is pending", function()
      session.deferred = true
      session.fail_below = BASE
      memory.open("0x404010")
      memory.refresh() -- e.g. event_stopped before the first read answered
      session:flush()
      local offsets = vim.tbl_map(function(r)
        return r.args.offset
      end, session:sent("readMemory"))
      assert.are.same({ -64, -64, 0 }, offsets) -- the first answer is dropped (older seq)
      assert.are.equal(0, memory.state().offset)
      assert.is_nil(memory.state().error)
      assert.are.equal(1, cursor_byte())
    end)

    it("refuses edits while the fallback read is pending", function()
      session.deferred = true
      session.fail_below = BASE
      memory.open("0x404010")
      session:flush(1) -- the context read fails, the retry at 0 is sent
      assert.are.equal(0, memory.state().pending.offset)
      memory.edit(1, 0x00)
      assert.is_not_nil(message_matching("still being read"))
      session:flush()
      assert.are.same({}, session:sent("writeMemory"))
      memory.edit(1, 0x00)
      session:flush()
      assert.are.equal(0x00, session.mem[BASE])
    end)

    it("pages keep the cursor where it is and the target highlight only where it is", function()
      memory.open("0x404010")
      assert.are.equal(2, #target_marks())
      vim.api.nvim_win_set_cursor(0, { 4, memory.state().view.render.layout.cells[3] })
      memory.page(1)
      assert.are.equal(192, memory.state().offset)
      assert.are.equal(19, cursor_byte())
      assert.are.same({}, target_marks())
      memory.page(-1)
      assert.are.equal(19, cursor_byte())
      assert.are.equal(2, #target_marks())
      memory.refresh()
      assert.are.equal(19, cursor_byte())
    end)

    it("edits and undoes bytes above and at the target with negative offsets", function()
      memory.open("0x404010")
      memory.edit(64, 0x7e) -- the byte just before the target
      memory.edit(65, 0x00) -- the target
      local writes = session:sent("writeMemory")
      assert.are.same({ memoryReference = "0x404010", offset = -1, data = "fg==" }, writes[1].args)
      assert.are.same({ memoryReference = "0x404010", offset = 0, data = "AA==" }, writes[2].args)
      assert.are.equal(0x7e, session.mem[BASE - 1])
      assert.truthy(lines()[6]:find(" 7e  |", 1, true))
      assert.are.equal(65, cursor_byte())
      -- The target keeps its highlight next to the written one.
      local layout = memory.state().view.render.layout
      assert.are.same({ { 6, layout.cells[1] }, { 6, layout.ascii_start } }, target_marks())
      memory.undo()
      memory.undo()
      assert.are.equal(0x41, session.mem[BASE])
      assert.are.equal(0x00, session.mem[BASE - 1]) -- what was read there before
    end)

    it("puts the cursor on the target in bits mode too", function()
      memory.open("0x404010")
      memory.toggle_mode()
      memory.jump("0x404012")
      local layout = memory.state().view.render.layout
      assert.are.equal("bits", layout.mode)
      assert.are.equal(-0x42, memory.state().offset)
      assert.are.equal(0x43, cursor_byte())
      assert.are.equal(1, #vim.tbl_filter(function(m)
        return m[2] == layout.cells[3]
      end, target_marks()))
    end)
  end)

  describe("keys", function()
    it("binds the documented keys in the view buffer", function()
      memory.open("0x404010")
      local bufnr = memory.state().view.surface.bufnr
      for _, lhs in ipairs({ "e", "<CR>", "<Space>", "<2-LeftMouse>", "u", "b", "a", "n", "p", "r" }) do
        local map = vim.fn.maparg(lhs, "n", false, true)
        assert.are.equal(1, map.buffer, lhs)
        assert.are.equal(bufnr, vim.api.nvim_get_current_buf())
      end
    end)

    it("b toggles the mode and e edits the byte under the cursor", function()
      memory.open("0x404010")
      assert.are.equal(memory.state().view.surface.winid, vim.api.nvim_get_current_win())
      -- The buffer-local mappings' own callbacks, as the key would run them.
      local function press(lhs)
        vim.fn.maparg(lhs, "n", false, true).callback()
      end

      -- The cursor starts on the first byte.
      press("e")
      assert.are.equal("41", prompts[#prompts].default)
      vim.api.nvim_win_set_cursor(0, { 4, memory.state().view.render.layout.cells[3] })
      press("<CR>")
      assert.are.equal("53", prompts[#prompts].default) -- byte 19 = 0x41 + 18
      press("b")
      assert.are.equal("bits", memory.state().mode)
      -- The new layout keeps the cursor on the same byte.
      assert.are.equal(19, (require("wkddap.memory.view").cursor_byte(memory.state().view)))
      -- Bits mode: row 2 of the page holds bytes 5..8; column 1 of cell 1 is bit 1.
      vim.api.nvim_win_set_cursor(0, { 4, memory.state().view.render.layout.cells[1] + 1 })
      press("<Space>")
      assert.are.equal(0x45 - 0x40, session.mem[BASE + 4]) -- 0x45 with bit 6 cleared
      press("u")
      assert.are.equal(0x45, session.mem[BASE + 4])
      press("n")
      assert.are.equal(256, memory.state().offset)
      press("p")
      assert.are.equal(0, memory.state().offset)
      press("a")
      assert.truthy(prompts[#prompts].title:find("address or expression"))
    end)

    it("<2-LeftMouse> acts on the byte (and bit) under the mouse, not the cursor", function()
      memory.open("0x404010")
      local view = memory.state().view
      local double_click = vim.fn.maparg("<2-LeftMouse>", "n", false, true).callback
      local real_getmousepos = vim.fn.getmousepos
      local mouse = {}
      vim.fn.getmousepos = function()
        return mouse
      end
      local ok, err = pcall(function()
        -- Hex mode: row 2, byte 3 of the row = byte 19 of the page -> prompt.
        mouse = { winid = view.surface.winid, line = 4, column = view.render.layout.cells[3] + 1 }
        double_click()
        assert.are.equal("53", prompts[#prompts].default)
        -- Bits mode: row 2 holds bytes 5..8; column 1 of cell 2 is bit 1 of byte 6.
        memory.toggle_mode()
        mouse = { winid = view.surface.winid, line = 4, column = view.render.layout.cells[2] + 2 }
        double_click()
        assert.are.equal(0x46 - 0x40, session.mem[BASE + 5])
        -- A click outside the view falls back to the cursor (byte 1 here).
        vim.api.nvim_win_set_cursor(view.surface.winid, { 3, view.render.layout.cells[1] })
        mouse = { winid = -1, line = 0, column = 0 }
        double_click()
        assert.are.equal(0xc1, session.mem[BASE]) -- 0x41 with the MSB set
      end)
      vim.fn.getmousepos = real_getmousepos
      assert(ok, err)
    end)
  end)
end)
