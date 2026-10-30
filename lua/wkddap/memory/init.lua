---@module 'wkddap.memory'
--- Memory view: a Visual-Studio-style hex/bits view of an address range of the
--- debuggee, over DAP `readMemory`/`writeMemory` of the nvim-dap session that
--- is already running -- in a float of this Neovim, with no second process and
--- no terminal.
---
--- Flow: `open(target)` checks the session and its capabilities, resolves the
--- target (a literal address is used as is; anything else is sent to the
--- adapter as an `evaluate` request: a value that is an address, else its
--- `memoryReference`, else the first "0x..." of the value, is used), then
--- reads one page (`format.PAGE_SIZE`
--- bytes) at `base + offset`. Paging only moves `offset`; the base reference
--- stays what the target resolved to, so the target is always offset 0.
---
--- Like Visual Studio's memory window, an open or a jump does not start the
--- page at the target: it starts `memory.context_rows` rows above it
--- (`format.context_offset`, row-aligned when the address is known), the
--- cursor lands on the target byte when that read answers, and the target
--- byte is highlighted whenever it is on the shown page. When that first read
--- does not reach the target (memory just before it unmapped, or an adapter
--- that stops at a region boundary), a second read starts where the first
--- stopped, or at the target, instead of showing the error or a page of `??`.
---
--- Requests are asynchronous, so the shown page (`base`, `label`, `offset`,
--- `bytes`) only ever changes as a whole, when a read answers: navigation
--- sets `pending` and the page it asks for is committed with its response.
--- Every read gets a sequence number and only the newest one is applied; a
--- write bumps the number too, so a read sent before it cannot bring back the
--- old byte. While a read for another page is pending, edits are refused --
--- `bytes` belongs to the page on screen, not to the one the user moved to.
---
--- Editing is byte-wise: one `writeMemory` of exactly one byte (base64) per
--- edit. The byte is updated in the view as the write is sent (so a second
--- edit of it builds on the first) and the page is re-read when the write
--- answers, so the view ends up showing what the adapter reports rather than
--- what was typed. Being byte-wise, endianness
--- never matters for an edit; the display is the byte order in memory, bits
--- MSB-first per byte. Every successful write pushes `{ ref, offset, old, new }`
--- on a plugin-side undo stack; `undo()` writes `old` back the same way. The
--- stack lives as long as the view; it is not the debuggee's history -- a byte
--- the program changed in between is overwritten by an undo all the same.
---
--- Window layer: the view draws on one of two implementations of the same
--- interface (`open/show/close/is_valid/focus_byte/cursor_byte`): the float
--- (`wkddap.memory.view`, the default, with the edit keys) or a read-only
--- companion window (`wkddap.memory.companion`: a second Neovim in its own
--- terminal, `lib.nvim.companion`; `:Dap memory-window`, `open(target,
--- { companion = true })`). State and requests stay here either way; the
--- companion only shows the page and sends its keys back as actions. One view
--- at a time: opening the other kind replaces the open one.
---
--- Session lifetime: nvim-dap listeners (`event_terminated`, `event_exited`,
--- `disconnect`) mark the view stale (read-only, title and header say so);
--- so does a session nvim-dap closed without any of those events (adapter
--- died, pipe closed, disconnect timed out), noticed through `session.closed`
--- on the next action. `event_stopped` and `event_memory` re-read the page.
--- The listeners are removed when the view closes.

local format = require("wkddap.memory.format")

local M = {}

---Listener key under `dap.listeners.after.<event>`.
local LISTENER = "wkddap.memory"

---Events that end the view's session, and events that make its page outdated.
local END_EVENTS = { "event_terminated", "event_exited", "disconnect" }
local REFRESH_EVENTS = { "event_stopped", "event_memory" }

---@class Dap.MemoryUndo
---@field ref string memoryReference the write went to
---@field offset integer offset from `ref`
---@field old integer value before the write
---@field new integer value written

---A page to read: where it is and what the user called it.
---@class Dap.MemoryTarget
---@field base string
---@field label string
---@field offset integer
---@field focus? boolean put the cursor on the target byte when this read commits (open, jump)
---@field context? boolean `offset` starts above the target for context rows: when the
---  read does not reach the target (an error, no byte, a region cut), read once more
---  from where it stopped, or from the target
---@field partial? { result: table, bytes: integer[], offset: integer } what the context
---  read got before it stopped; shown instead when this re-read gets nothing

---@class Dap.MemoryState
---@field session table the nvim-dap session the view reads from
---@field base string memoryReference all offsets are relative to (shown page)
---@field label string what the user asked for (shown page)
---@field offset integer page start relative to `base` (shown page)
---@field mode Dap.MemoryMode
---@field bytes integer[] the shown page's bytes
---@field address integer|nil
---@field unreadable integer
---@field error string|nil
---@field stale boolean
---@field undo Dap.MemoryUndo[]
---@field window Dap.MemoryWindow which window layer `view` belongs to
---@field view Dap.MemoryView|Dap.MemoryCompanionView|nil
---@field pending Dap.MemoryTarget|nil the page the newest read asks for, until it answers
---@field seq integer number of the newest read; a response with another one is dropped

---@alias Dap.MemoryWindow "float"|"companion"

---Options of `open()`.
---@class Dap.MemoryOpenOpts
---@field companion? boolean show the view in a read-only companion window instead of the float
---@field terminal? string[]|false companion only: the terminal argv template, or false for a
---  headless companion (scripts); nil = the platform's default terminal

---The one open view (nil when none). A second `open()` reuses its window.
---@type Dap.MemoryState|nil
local current = nil

---The window layer modules by kind.
---@type table<Dap.MemoryWindow, string>
local WINDOW_MODULES = { float = "wkddap.memory.view", companion = "wkddap.memory.companion" }

---The window layer `state` draws on.
---@internal
---@param state Dap.MemoryState
---@return table
local function view_module(state)
  return require(WINDOW_MODULES[state.window] or WINDOW_MODULES.float)
end

---The last target the user typed, to pre-fill the next prompt.
---@type string|nil
local last_target = nil

---@internal
---@return table
local function notify()
  return require("wkddap.utils.notify")
end

---@internal
---@return table|nil
local function get_dap()
  local ok, dap = pcall(require, "dap")
  if not ok or type(dap) ~= "table" then
    return nil
  end
  return dap
end

---@internal
---@param session table
---@return string
local function adapter_name(session)
  local config = type(session.config) == "table" and session.config or {}
  return tostring(config.type or config.name or "debug adapter")
end

---Does `session` advertise `capability`? Notifies (and returns false) when not.
---@internal
---@param session table
---@param capability string
---@param what string
---@return boolean
local function supports(session, capability, what)
  local caps = type(session.capabilities) == "table" and session.capabilities or {}
  if caps[capability] then
    return true
  end
  notify().warn(
    ("Memory view: the debug adapter '%s' does not support %s (%s is not set)."):format(
      adapter_name(session),
      what,
      capability
    )
  )
  return false
end

---Send a request, delivering the result on the main loop (nvim-dap already
---does, an adapter double may not) and turning a raised error into an error
---response instead of a traceback.
---@internal
---@param session table
---@param command string
---@param args table
---@param cb fun(err: any, result: any)
local function request(session, command, args, cb)
  local function deliver(err, result)
    if vim.in_fast_event() then
      vim.schedule(function()
        cb(err, result)
      end)
    else
      cb(err, result)
    end
  end
  local ok, raised = pcall(session.request, session, command, args, deliver)
  if not ok then
    deliver({ message = tostring(raised) }, nil)
  end
end

---Turn what the user typed into a memoryReference.
---@internal
---@param session table
---@param target string
---@param cb fun(ref: string|nil, err: string|nil)
local function resolve(session, target, cb)
  local literal = format.literal_reference(target)
  if literal then
    cb(literal, nil)
    return
  end
  local frame = type(session.current_frame) == "table" and session.current_frame or nil
  local function evaluate(expression, on_result)
    request(session, "evaluate", {
      expression = expression,
      frameId = frame and frame.id or nil,
      context = "watch",
    }, on_result)
  end
  evaluate(target, function(err, result)
    if err then
      cb(nil, ("could not evaluate %q: %s"):format(target, format.error_message(err)))
      return
    end
    result = type(result) == "table" and result or {}
    local function refuse()
      cb(
        nil,
        ("%q is not an address (it evaluated to %s); try &%s"):format(
          target,
          tostring(result.result),
          target
        )
      )
    end
    -- A value that is an address wins (Visual Studio's rule: the expression's
    -- value is where to look). For a pointer, lldb-dap's memoryReference is
    -- where the pointer itself is stored, GDB's is where it points; the value
    -- is the same on both. Only a hex value counts: `n` evaluating to `42` is
    -- a number, not address 0x2a.
    local value = type(result.result) == "string" and vim.trim(result.result) or ""
    if value:match("^0[xX]%x+$") then
      cb(value, nil)
      return
    end
    if type(result.memoryReference) == "string" and result.memoryReference ~= "" then
      cb(result.memoryReference, nil)
      return
    end
    local addr = format.find_reference(result.result)
    if addr then
      cb(addr, nil)
      return
    end
    -- codelldb shows a pointer to characters as the string it points to
    -- ("ABC..." for `&buffer`, type `unsigned char (*)[32]`) and sets no
    -- memoryReference; its `,x` format specifier gives the pointer in hex.
    -- Only tried for a pointer type, so a plain number is still refused.
    local kind = type(result.type) == "string" and result.type or ""
    if not kind:find("*", 1, true) then
      refuse()
      return
    end
    evaluate(target .. ",x", function(err2, hex)
      hex = not err2 and type(hex) == "table" and format.find_reference(hex.result) or nil
      if hex then
        cb(hex, nil)
        return
      end
      refuse()
    end)
  end)
end

---@internal
---@param state Dap.MemoryState
---@return string
local function title(state)
  return state.stale and " Memory [stale] " or " Memory "
end

---Page index of the target byte (offset 0 from the base) on a page starting
---at `offset`, or nil when the target is not on that page.
---@internal
---@param offset integer
---@return integer|nil
local function target_index(offset)
  local index = -offset + 1
  if index >= 1 and index <= format.PAGE_SIZE then
    return index
  end
  return nil
end

---`memory.context_rows` of the active config (0 when unreadable).
---@internal
---@return integer
local function context_rows()
  local ok, cfg = pcall(function()
    return require("wkddap.config").get()
  end)
  local memory = ok and type(cfg) == "table" and cfg.memory or nil
  local rows = type(memory) == "table" and memory.context_rows or nil
  return type(rows) == "number" and rows or 0
end

---The first page of an open or a jump to `ref`: `context_rows()` rows above
---the target, cursor on the target when it answers.
---@internal
---@param ref string
---@param label string
---@return Dap.MemoryTarget
local function first_page(ref, label)
  local offset =
    format.context_offset(format.exact_address(format.parse_address(ref)), context_rows())
  return { base = ref, label = label, offset = offset, focus = true, context = offset ~= 0 }
end

---@internal
---@param state Dap.MemoryState
---@return Dap.MemoryRender
local function render_of(state)
  local written = {}
  for _, entry in ipairs(state.undo) do
    if entry.ref == state.base then
      local index = entry.offset - state.offset + 1
      if index >= 1 and index <= format.PAGE_SIZE then
        written[index] = true
      end
    end
  end
  return format.render({
    label = state.label,
    mode = state.mode,
    offset = state.offset,
    count = format.PAGE_SIZE,
    bytes = state.bytes,
    address = state.address,
    unreadable = state.unreadable,
    error = state.error,
    stale = state.stale,
    written = written,
    target = target_index(state.offset),
  })
end

---@internal
---@param state Dap.MemoryState
local function redraw(state)
  if state.view then
    view_module(state).show(state.view, render_of(state), title(state))
  end
end

---@internal
---@param state Dap.MemoryState
---@return boolean
local function usable(state)
  -- nvim-dap closes a session without terminated/exited/disconnect events
  -- when the adapter dies or its pipe closes, and when a disconnect times out.
  if not state.stale and type(state.session) == "table" and state.session.closed then
    state.stale = true
    redraw(state)
  end
  if state.stale then
    notify().warn("Memory view: the debug session has ended; reopen it with :Dap memory.")
    return false
  end
  return true
end

---Is a read for another page than the shown one still pending? Then `bytes`
---does not belong to where the user is going, and edits must wait.
---@internal
---@param state Dap.MemoryState
---@return boolean
local function navigating(state)
  local p = state.pending
  return p ~= nil and (p.base ~= state.base or p.offset ~= state.offset)
end

---The page the view is on or moving to: the pending read's, else the shown one.
---@internal
---@param state Dap.MemoryState
---@return Dap.MemoryTarget
local function target_of(state)
  return state.pending or { base = state.base, label = state.label, offset = state.offset }
end

---Read the page `target` (default: `target_of(state)`), then make it the
---shown page and redraw. A response that is no longer the newest read is
---dropped.
---@internal
---@param state Dap.MemoryState
---@param target? Dap.MemoryTarget
local function read(state, target)
  target = target or target_of(state)
  -- Only the read that opens/jumps carries `focus`/`context`; a re-read of
  -- that pending page (refresh, a write answering) keeps them, so the cursor
  -- still lands on the target and the fallback still applies.
  state.pending = target
  state.seq = state.seq + 1
  local seq = state.seq
  request(state.session, "readMemory", {
    memoryReference = target.base,
    offset = target.offset,
    count = format.PAGE_SIZE,
  }, function(err, result)
    if current ~= state or state.seq ~= seq then
      return -- the view was closed or replaced, or a newer read/write was sent
    end
    result = type(result) == "table" and result or {}
    local bytes = not err and format.decode(result.data) or {}
    -- The context rows above the target may be unmapped (the start of a
    -- mapping), or the adapter stops at a region boundary before the target:
    -- codelldb reads one region only (32 bytes and 224 "unreadable" where the
    -- next region holds the target). GDB fails the whole read; lldb-dap and
    -- codelldb answer with success and what they got, `data` contiguous from
    -- the start. A read that does not reach the target is followed by one
    -- from where it stopped (rounded up to a row), or from the target itself
    -- when it got nothing -- never a page of `??` for a readable target.
    local at = target_index(target.offset)
    if target.context and at and #bytes < at then
      local row = format.CONTEXT_ROW
      local from = 0
      if #bytes > 0 then
        from = -math.floor(-(target.offset + #bytes) / row) * row
      end
      read(state, {
        base = target.base,
        label = target.label,
        offset = from,
        focus = target.focus,
        partial = #bytes > 0 and { result = result, bytes = bytes, offset = target.offset } or nil,
      })
      return
    end
    if target.partial and (err or #bytes == 0) then
      -- The re-read got nothing: the target itself is unreadable, and the
      -- context rows the first read got are worth more than a page of `??`.
      err, result, bytes = nil, target.partial.result, target.partial.bytes
      target = {
        base = target.base,
        label = target.label,
        offset = target.partial.offset,
        focus = target.focus,
      }
    end
    state.pending = nil
    state.base, state.label, state.offset = target.base, target.label, target.offset
    if err then
      state.bytes, state.address, state.unreadable = {}, nil, 0
      state.error = format.error_message(err)
      notify().warn("Memory view: readMemory failed: " .. state.error)
    else
      state.error = nil
      state.bytes = bytes
      state.unreadable = tonumber(result.unreadableBytes) or 0
      local base = format.exact_address(format.parse_address(state.base))
      state.address = format.exact_address(format.parse_address(result.address))
        or format.exact_address(base and base + state.offset or nil)
    end
    redraw(state)
    local index = target.focus and target_index(target.offset)
    if index and state.view then
      view_module(state).focus_byte(state.view, index)
    end
  end)
end

---Write one byte, show it on the page right away (when the page shows that
---location) and re-read the page when the write answers. The write also
---outdates every read sent before it.
---@internal
---@param state Dap.MemoryState
---@param ref string
---@param offset integer
---@param value integer
---@param on_done fun(ok: boolean)
local function write(state, ref, offset, value, on_done)
  local index = offset - state.offset + 1
  if ref == state.base and not navigating(state) and state.bytes[index] ~= nil then
    state.bytes[index] = value
    redraw(state)
  end
  state.seq = state.seq + 1
  request(state.session, "writeMemory", {
    memoryReference = ref,
    offset = offset,
    data = format.encode({ value }),
  }, function(err, result)
    local ok = true
    if err then
      notify().warn("Memory view: writeMemory failed: " .. format.error_message(err))
      ok = false
    elseif type(result) == "table" and result.bytesWritten == 0 then
      notify().warn("Memory view: writeMemory wrote nothing (bytesWritten = 0).")
      ok = false
    end
    on_done(ok)
    -- Also after a failure: the byte shown early must go back to the truth.
    if current == state and not state.stale then
      read(state)
    end
  end)
end

---Remove every listener this module installed.
---@internal
local function detach_listeners()
  local dap = get_dap()
  if not dap or not dap.listeners then
    return
  end
  for _, event in ipairs(vim.list_extend(vim.list_extend({}, END_EVENTS), REFRESH_EVENTS)) do
    local tbl = dap.listeners.after[event]
    if tbl and tbl[LISTENER] then
      tbl[LISTENER] = nil
    end
  end
end

---@internal
---@param state Dap.MemoryState
local function attach_listeners(state)
  local dap = get_dap()
  if not dap or not dap.listeners then
    return
  end
  local after = dap.listeners.after
  local function on(event, fn)
    -- nvim-dap creates the per-event tables lazily (metatable); a plain
    -- table (an older nvim-dap, a test double) may not have them yet.
    local tbl = after[event]
    if not tbl then
      tbl = {}
      after[event] = tbl
    end
    tbl[LISTENER] = fn
  end
  for _, event in ipairs(END_EVENTS) do
    on(event, function(session)
      if current == state and session == state.session and not state.stale then
        state.stale = true
        redraw(state)
      end
    end)
  end
  for _, event in ipairs(REFRESH_EVENTS) do
    on(event, function(session)
      if current == state and session == state.session and not state.stale then
        read(state)
      end
    end)
  end
end

---@internal
---@param state Dap.MemoryState
local function forget(state)
  if current == state then
    detach_listeners()
    current = nil
  end
end

-- Actions ------------------------------------------------------------------

---Prompt for a byte value and write it to byte `index` of the page.
---@param index integer|nil 1-based index within the page
---@param value? integer when given, written without a prompt
function M.edit(index, value)
  local state = current
  if not state or not usable(state) then
    return
  end
  if not supports(state.session, "supportsWriteMemoryRequest", "writing memory") then
    return
  end
  if not index then
    notify().info("Memory view: put the cursor on a byte to edit it.")
    return
  end
  if navigating(state) then
    notify().info("Memory view: the page is still being read; try again in a moment.")
    return
  end
  local old = state.bytes[index]
  if old == nil then
    notify().warn("Memory view: that byte is unreadable and cannot be edited.")
    return
  end
  local base, offset = state.base, state.offset + index - 1

  local function apply(new)
    -- From a prompt this runs later: the page may have moved or been re-read
    -- meanwhile, so `old` is taken again from the page as it is now.
    if current ~= state or not usable(state) then
      return
    end
    local now = state.base == base and state.bytes[offset - state.offset + 1] or nil
    if navigating(state) or now == nil then
      notify().info("Memory view: the page changed meanwhile; edit the byte again.")
      return
    end
    if new == now then
      return
    end
    write(state, base, offset, new, function(ok)
      if ok then
        table.insert(state.undo, { ref = base, offset = offset, old = now, new = new })
      end
    end)
  end

  if value ~= nil then
    apply(value)
    return
  end
  local where = state.address and format.hex_address(state.address + index - 1)
    or ("%s%+d"):format(state.label, offset)
  require("ui.kit").input({
    title = ("Byte at %s: "):format(where),
    default = state.mode == "bits" and format.bits(old) or format.hex(old, 2),
    on_submit = function(text)
      if text == nil then
        return
      end
      local new, err = format.parse_byte(text, state.mode)
      if not new then
        notify().warn("Memory view: " .. err)
        return
      end
      apply(new)
    end,
  })
end

---Flip bit `bit` (0 = MSB) of byte `index`. Bits mode only.
---@param index integer|nil
---@param bit integer|nil
function M.toggle_bit(index, bit)
  local state = current
  if not state then
    return
  end
  if state.mode ~= "bits" or bit == nil then
    notify().info("Memory view: switch to bits mode (b) and put the cursor on a bit to flip it.")
    return
  end
  local old = state.bytes[index or 0]
  if old == nil then
    M.edit(index) -- same checks and messages as an edit
    return
  end
  M.edit(index, format.toggle_bit(old, bit))
end

---A double-click: flips the bit under the mouse in bits mode, prompts for
---the byte otherwise.
---@param index integer|nil
---@param bit integer|nil
function M.click(index, bit)
  local state = current
  if state and state.mode == "bits" and bit ~= nil then
    M.toggle_bit(index, bit)
  else
    M.edit(index)
  end
end

---Write back the value from before the most recent write of this view.
function M.undo()
  local state = current
  if not state or not usable(state) then
    return
  end
  local entry = table.remove(state.undo)
  if not entry then
    notify().info("Memory view: nothing to undo.")
    return
  end
  if not supports(state.session, "supportsWriteMemoryRequest", "writing memory") then
    table.insert(state.undo, entry)
    return
  end
  write(state, entry.ref, entry.offset, entry.old, function(ok)
    if not ok then
      table.insert(state.undo, entry) -- keep it for another try
    end
  end)
end

---Switch between hex and bits.
function M.toggle_mode()
  local state = current
  if not state then
    return
  end
  state.mode = state.mode == "hex" and "bits" or "hex"
  redraw(state)
end

---Move by `delta` pages (negative = back) and re-read.
---@param delta integer
function M.page(delta)
  local state = current
  if not state or not usable(state) then
    return
  end
  -- From the page the view is moving to, so that `nn` goes two pages even
  -- before the first read answers.
  local from = target_of(state)
  local offset = from.offset + delta * format.PAGE_SIZE
  local base = format.exact_address(format.parse_address(from.base))
  if base and base + offset < 0 then
    notify().info("Memory view: there is no page below address 0.")
    return
  end
  read(state, { base = from.base, label = from.label, offset = offset })
end

---Re-read the current page.
function M.refresh()
  local state = current
  if not state or not usable(state) then
    return
  end
  read(state)
end

---@internal
---@param session table
---@param target string
---@param window Dap.MemoryWindow
---@param opts Dap.MemoryOpenOpts
local function show(session, target, window, opts)
  resolve(session, target, function(ref, err)
    if not ref then
      notify().warn("Memory view: " .. tostring(err))
      return
    end
    last_target = target

    local state = current
    if
      state
      and state.session == session
      and state.window == window
      and view_module(state).is_valid(state.view)
    then
      -- Same session, same kind of window, still open: move it, keep mode and
      -- undo stack. The new place becomes the shown page when its read answers.
      state.stale = false
      read(state, first_page(ref, target))
      return
    end
    local page = first_page(ref, target)
    if state then
      -- Another session, a closed window, or the other kind of window.
      local old_view, old_module = state.view, view_module(state)
      forget(state)
      old_module.close(old_view)
    end

    ---@type Dap.MemoryState
    state = {
      session = session,
      base = ref,
      label = target,
      offset = page.offset,
      mode = "hex",
      bytes = {},
      address = nil,
      unreadable = 0,
      error = nil,
      stale = false,
      undo = {},
      window = window,
      view = nil,
      pending = nil,
      seq = 0,
    }
    current = state
    local view_mod = view_module(state)
    local open_err
    state.view, open_err = view_mod.open(render_of(state), title(state), {
      edit = M.edit,
      toggle_bit = M.toggle_bit,
      click = M.click,
      undo = M.undo,
      toggle_mode = M.toggle_mode,
      jump = function(to)
        M.jump(to)
      end,
      page = M.page,
      refresh = M.refresh,
      closed = function()
        forget(state)
      end,
    }, { terminal = opts.terminal })
    if not state.view then
      forget(state)
      notify().error(
        "Memory view: could not open the window" .. (open_err and (": " .. open_err) or ".")
      )
      return
    end
    attach_listeners(state)
    local index = target_index(page.offset)
    if index then
      view_mod.focus_byte(state.view, index)
    end
    read(state, page)
  end)
end

---The session to read from, or nil (with a message) when there is none that
---can read memory.
---@internal
---@return table|nil
local function active_session()
  local dap = get_dap()
  if not dap then
    notify().warn("Memory view: nvim-dap is not installed.")
    return nil
  end
  local session = type(dap.session) == "function" and dap.session() or nil
  if not session then
    notify().warn("Memory view: no debug session is running.")
    return nil
  end
  if not supports(session, "supportsReadMemoryRequest", "reading memory") then
    return nil
  end
  return session
end

---@internal
---@return string
local function prompt_default()
  if current then
    return current.label
  end
  if last_target then
    return last_target
  end
  local word = vim.fn.expand("<cword>")
  if word:match("^[%a_][%w_]*$") then
    return "&" .. word
  end
  return ""
end

---@internal
---@param session table
---@param window Dap.MemoryWindow
---@param opts Dap.MemoryOpenOpts
local function prompt(session, window, opts)
  require("ui.kit").input({
    title = "Memory address or expression: ",
    default = prompt_default(),
    on_submit = function(text)
      text = text and vim.trim(text) or ""
      if text ~= "" then
        show(session, text, window, opts)
      end
    end,
  })
end

---Go to another address or expression in the open view (prompts when
---`target` is omitted). The view keeps its kind of window.
---@param target? string
function M.jump(target)
  local state = current
  if not state or not usable(state) then
    return
  end
  if target and vim.trim(target) ~= "" then
    show(state.session, vim.trim(target), state.window, {})
  else
    prompt(state.session, state.window, {})
  end
end

---Open the memory view at `target` -- a literal address ("0x404010") or an
---expression the adapter evaluates to an address ("&buffer", "ptr") -- in the
---active nvim-dap session. Prompts when `target` is omitted. In the float by
---default; `opts.companion` shows it in a read-only companion window instead
---(`wkddap.memory.companion`).
---@param target? string
---@param opts? Dap.MemoryOpenOpts
function M.open(target, opts)
  opts = opts or {}
  local session = active_session()
  if not session then
    return
  end
  local window = opts.companion and "companion" or "float"
  if target and vim.trim(target) ~= "" then
    show(session, vim.trim(target), window, opts)
  else
    prompt(session, window, opts)
  end
end

---Close the view, if one is open.
function M.close()
  local state = current
  if state then
    local view, view_mod = state.view, view_module(state)
    forget(state)
    view_mod.close(view)
  end
end

---The open view's state (nil when none). For tests and introspection; treat
---it as read-only.
---@return Dap.MemoryState|nil
function M.state()
  return current
end

return M
