--- Covers the memory view in a companion window: wkddap.memory with
--- wkddap.memory.companion as its window layer, driven by the same fake
--- nvim-dap session as init_spec.lua and a FAKE lib.nvim.companion (no second
--- process, no terminal, no RPC: `.testing.lua` forbids all of them). The fake
--- records what the view pushes (lines, highlights, title) and lets a spec
--- "press" a companion key: it resolves the key to its action and runs it the
--- way the companion's keymap would, prompt text included.
---
--- nvim-dap itself is never loaded: `package.loaded["dap"]` is a stand-in
--- (TESTS/README.md), as are wkddap.utils.notify and ui.kit's `input`.

local format = require("wkddap.memory.format")

local BASE = 0x404010

---A debug-adapter double over a byte table (the read/write subset of the one
---in init_spec.lua).
local function fake_session()
  local s = {
    capabilities = { supportsReadMemoryRequest = true, supportsWriteMemoryRequest = true },
    config = { type = "gdb" },
    current_frame = { id = 7 },
    mem = {},
    requests = {},
    expressions = {
      ["&buffer"] = { result = "(char (*)[32]) 0x404010 <buffer>", memoryReference = "0x404010" },
    },
  }
  for i = 0, 1023 do
    s.mem[BASE - 512 + i] = (0x41 + i) % 256
  end

  function s:request(command, args, cb)
    table.insert(self.requests, { command = command, args = vim.deepcopy(args) })
    if command == "evaluate" then
      local hit = self.expressions[args.expression]
      if hit then
        cb(nil, hit)
      else
        cb({ message = 'No symbol "' .. args.expression .. '" in current context.' }, nil)
      end
    elseif command == "readMemory" then
      local addr = format.parse_address(args.memoryReference) + (args.offset or 0)
      local data = {}
      for i = 0, args.count - 1 do
        data[#data + 1] = self.mem[addr + i] or 0
      end
      cb(
        nil,
        { address = format.hex_address(addr), data = format.encode(data), unreadableBytes = 0 }
      )
    elseif command == "writeMemory" then
      local addr = format.parse_address(args.memoryReference) + (args.offset or 0)
      for i, b in ipairs(format.decode(args.data)) do
        self.mem[addr + i - 1] = b
      end
      cb(nil, nil)
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

---A lib.nvim.companion double: `open` records its options and returns a
---handle that records every update / title and can be closed from either
---side. `fail` makes `open` refuse.
local function fake_companion()
  local C = { opened = {}, fail = nil }

  function C.open(opts)
    if C.fail then
      return nil, C.fail
    end
    local h = {
      opts = opts,
      title = opts.title,
      lines = opts.lines,
      highlights = opts.highlights,
      updates = 0,
      titles = {},
      open = true,
      closed_calls = 0,
    }
    function h:update(lines, highlights)
      if not self.open then
        return false, "closed"
      end
      self.updates = self.updates + 1
      self.lines, self.highlights = lines, highlights
      return true
    end
    function h:set_title(title)
      if not self.open then
        return false
      end
      self.title = title
      table.insert(self.titles, title)
      return true
    end
    function h:is_open()
      return self.open
    end
    function h:is_attached()
      return self.open
    end
    ---`close()` from the main side, or the companion leaving (`q`): both end
    ---in `on_close` once.
    function h:close()
      if not self.open then
        return
      end
      self.open = false
      self.closed_calls = self.closed_calls + 1
      if opts.on_close then
        opts.on_close()
      end
    end
    ---A key pressed in the companion: resolved like the companion's keymap,
    ---`text` standing in for the answer of the key's prompt.
    ---@param lhs string
    ---@param text? string
    function h:press(lhs, text)
      local spec = opts.keys[lhs]
      assert(spec ~= nil, "no companion key " .. lhs)
      local name, args = spec, {}
      if type(spec) == "table" then
        name = spec[1]
        for i = 2, #spec do
          args[#args + 1] = spec[i]
        end
        if spec.prompt then
          if text == nil then
            return -- the prompt was cancelled: the companion sends nothing
          end
          args[#args + 1] = text
        end
      end
      opts.actions[name](unpack(args))
    end
    table.insert(C.opened, h)
    return h
  end

  return C
end

describe("wkddap.memory in a companion window", function()
  local memory, session, messages, prompts, listeners, comp

  local function handle()
    return comp.opened[#comp.opened]
  end

  local function message_matching(pattern)
    for _, m in ipairs(messages) do
      if m.msg:find(pattern, 1, true) then
        return m
      end
    end
    return nil
  end

  local function floats()
    local n = 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        n = n + 1
      end
    end
    return n
  end

  before_each(function()
    messages, prompts = {}, {}
    session = fake_session()
    comp = fake_companion()
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
    package.loaded["lib.nvim.companion"] = comp
    package.loaded["wkddap.memory"] = nil
    memory = require("wkddap.memory")
    require("wkddap.config").setup({ memory = { context_rows = 0 } })
  end)

  after_each(function()
    require("wkddap.config").setup({})
    memory.close()
    package.loaded["dap"] = nil
    package.loaded["wkddap.utils.notify"] = nil
    package.loaded["ui.kit"] = nil
    package.loaded["lib.nvim.companion"] = nil
    package.loaded["wkddap.memory"] = nil
  end)

  describe("opening", function()
    it("opens a companion instead of a float and pushes the rendered page", function()
      local before = floats()
      memory.open("0x404010", { companion = true })
      assert.are.equal(before, floats())
      assert.are.equal(1, #comp.opened)
      local h = handle()
      assert.are.equal("companion", memory.state().window)
      assert.are.equal(" Memory ", h.opts.title)
      assert.are.equal("wkddap-memory", h.opts.filetype)
      -- The read answered synchronously: one update after the initial content.
      assert.are.equal(1, h.updates)
      assert.are.equal("0x404010  @ 0x404010  (+0x0)  [hex]", h.lines[1])
      assert.are.equal(
        "0x00404010  41 42 43 44 45 46 47 48  49 4a 4b 4c 4d 4e 4f 50  |ABCDEFGHIJKLMNOP|",
        h.lines[3]
      )
      assert.are.equal(2 + 16 + 2, #h.lines) -- header, ruler, 16 rows, blank, legend
      assert.are.equal(require("wkddap.memory.companion").LEGEND, h.lines[#h.lines])
    end)

    it("renders the same lines as the float does", function()
      memory.open("0x404010", { companion = true })
      local pushed = vim.list_slice(handle().lines, 1, #handle().lines - 2)
      memory.open("0x404010")
      local float_lines =
        vim.api.nvim_buf_get_lines(memory.state().view.surface.bufnr, 0, -1, false)
      assert.are.same(pushed, vim.list_slice(float_lines, 1, #float_lines - 2))
    end)

    it("offers no edit keys, only navigation", function()
      memory.open("0x404010", { companion = true })
      local keys = handle().opts.keys
      local names = vim.tbl_keys(keys)
      table.sort(names)
      assert.are.same({ "a", "b", "n", "p", "r" }, names)
      for _, lhs in ipairs({ "e", "<CR>", "<Space>", "u" }) do
        assert.is_nil(keys[lhs], lhs)
      end
      assert.is_nil(handle().opts.actions.edit)
      assert.is_nil(handle().opts.actions.undo)
      assert.truthy(keys.a.prompt:find("address or expression"))
      local legend = handle().lines[#handle().lines]
      assert.is_nil(legend:find("edit", 1, true))
      assert.is_nil(legend:find("undo", 1, true))
    end)

    it("sends the target highlight as Search (the plugin's group is unknown there)", function()
      require("wkddap.config").setup({}) -- 4 context rows: the target is on row 5
      memory.open("0x404010", { companion = true })
      local search, own, legend = 0, 0, 0
      for _, hl in ipairs(handle().highlights) do
        assert.is_number(hl.line)
        assert.is_number(hl.col_start)
        assert.is_number(hl.col_end)
        assert.is_string(hl.group)
        if hl.group == "Search" then
          search = search + 1
        elseif hl.group == format.TARGET_GROUP then
          own = own + 1
        elseif hl.group == "Comment" and hl.line == #handle().lines - 1 then
          legend = legend + 1
        end
      end
      assert.are.equal(2, search) -- the cell and its ASCII character
      assert.are.equal(0, own)
      assert.are.equal(1, legend)
    end)

    it("prompts in this instance when no target is given", function()
      memory.open(nil, { companion = true })
      assert.are.equal(1, #prompts)
      prompts[1].on_submit("0x404010")
      assert.are.equal(1, #comp.opened)
      assert.are.equal("companion", memory.state().window)
    end)

    it("reports why when the companion cannot be started", function()
      comp.fail = "no terminal found"
      memory.open("0x404010", { companion = true })
      local m = message_matching("could not open the window: no terminal found")
      assert.is_not_nil(m)
      assert.are.equal("error", m.level)
      assert.is_nil(memory.state())
      assert.is_nil((listeners.after.event_terminated or {})["wkddap.memory"]) -- never attached
    end)

    it("passes the terminal option through (headless companions for scripts)", function()
      memory.open("0x404010", { companion = true, terminal = false })
      assert.is_false(handle().opts.terminal)
    end)
  end)

  describe("keys in the companion", function()
    it("n/p page from the companion and push the new page", function()
      memory.open("0x404010", { companion = true })
      local h = handle()
      h:press("n")
      assert.are.equal(256, memory.state().offset)
      assert.truthy(h.lines[3]:find("^0x00404110 "))
      h:press("p")
      h:press("p")
      assert.are.equal(-256, memory.state().offset)
      assert.truthy(h.lines[3]:find("^0x00403f10 "))
      assert.are.equal(4, h.updates)
    end)

    it("b toggles hex/bits, r re-reads", function()
      memory.open("0x404010", { companion = true })
      local h = handle()
      h:press("b")
      assert.are.equal("bits", memory.state().mode)
      assert.truthy(h.lines[1]:find("[bits]", 1, true))
      assert.are.equal("0x00404010  01000001 01000010 01000011 01000100  |ABCD|", h.lines[3])
      h:press("b")
      assert.are.equal("hex", memory.state().mode)
      session.mem[BASE] = 0x00
      h:press("r")
      assert.are.equal(2, #session:sent("readMemory"))
      assert.truthy(h.lines[3]:find("^0x00404010  00 42"))
    end)

    it("a jumps to the text the companion's prompt got, in the same companion", function()
      memory.open("0x404010", { companion = true })
      local h = handle()
      h:press("a", "&buffer")
      assert.are.equal(1, #comp.opened)
      assert.are.equal("&buffer", memory.state().label)
      assert.truthy(h.lines[1]:find("^&buffer  @ 0x404010"))
      assert.are.equal(1, #session:sent("evaluate"))
      -- A cancelled or empty prompt does nothing, and opens no prompt here.
      h:press("a")
      h:press("a", "   ")
      assert.are.equal("&buffer", memory.state().label)
      assert.are.same({}, prompts)
      assert.are.equal(1, #session:sent("evaluate"))
    end)

    it("reports an unknown expression from the companion as a warning here", function()
      memory.open("0x404010", { companion = true })
      handle():press("a", "nosuch")
      assert.is_not_nil(message_matching("No symbol"))
      assert.are.equal("0x404010", memory.state().label)
    end)
  end)

  describe("session lifetime", function()
    it("marks the companion stale when the session ends: title and header", function()
      memory.open("0x404010", { companion = true })
      local h = handle()
      listeners.after.event_terminated["wkddap.memory"](session, {})
      assert.is_true(memory.state().stale)
      assert.are.equal(" Memory [stale] ", h.title)
      assert.truthy(h.lines[1]:find("[stale: session ended]", 1, true))
      assert.is_true(h:is_open()) -- the last page stays readable
      h:press("r")
      assert.is_not_nil(message_matching("session has ended"))
      assert.are.equal(1, #session:sent("readMemory"))
    end)

    it("re-reads and pushes when the debuggee stops again", function()
      memory.open("0x404010", { companion = true })
      local h = handle()
      session.mem[BASE] = 0x7a
      listeners.after.event_stopped["wkddap.memory"](session, {})
      assert.are.equal(2, #session:sent("readMemory"))
      assert.truthy(h.lines[3]:find("^0x00404010  7a 42"))
    end)

    it("forgets the view and its listeners when the companion is closed over there (q)", function()
      memory.open("0x404010", { companion = true })
      handle():close() -- the companion left: on_close
      assert.is_nil(memory.state())
      for _, event in ipairs({ "event_terminated", "event_exited", "disconnect", "event_stopped" }) do
        assert.is_nil(listeners.after[event]["wkddap.memory"], event)
      end
      -- A late answer or event does not revive it.
      listeners.after.event_stopped["wkddap.memory"] = nil
      assert.are.equal(1, #session:sent("readMemory"))
    end)

    it("close() closes the companion once", function()
      memory.open("0x404010", { companion = true })
      local h = handle()
      memory.close()
      assert.is_false(h:is_open())
      assert.are.equal(1, h.closed_calls)
      assert.is_nil(memory.state())
      memory.close()
      assert.are.equal(1, h.closed_calls)
    end)
  end)

  describe("float and companion", function()
    it(":Dap memory-window replaces an open float, :Dap memory replaces the companion", function()
      memory.open("0x404010")
      local winid = memory.state().view.surface.winid
      assert.are.equal("float", memory.state().window)
      memory.open("0x404010", { companion = true })
      assert.is_false(vim.api.nvim_win_is_valid(winid))
      assert.are.equal("companion", memory.state().window)
      local h = handle()
      memory.open("0x404010")
      assert.is_false(h:is_open())
      assert.are.equal("float", memory.state().window)
      assert.is_true(vim.api.nvim_win_is_valid(memory.state().view.surface.winid))
      assert.are.equal(1, #comp.opened)
    end)

    it("a second open in the companion reuses it, keeping mode and undo", function()
      memory.open("0x404010", { companion = true })
      memory.toggle_mode()
      memory.edit(1, 0x00) -- the API still works; the companion has no key for it
      memory.open("&buffer", { companion = true })
      assert.are.equal(1, #comp.opened)
      assert.are.equal("bits", memory.state().mode)
      assert.are.equal(1, #memory.state().undo)
      assert.are.equal("&buffer", memory.state().label)
    end)

    it("jump() keeps the kind of window", function()
      memory.open("0x404010", { companion = true })
      memory.jump("0x404110")
      assert.are.equal("companion", memory.state().window)
      assert.are.equal(1, #comp.opened)
      assert.are.equal("0x404110", memory.state().label)
    end)
  end)
end)
