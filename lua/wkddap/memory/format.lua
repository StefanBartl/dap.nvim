---@module 'wkddap.memory.format'
--- Pure helpers of the memory view: base64 <-> byte lists, address and byte
--- parsing, and the text layout of a page (hex or bits) including the map from
--- a cursor column back to the byte (and bit) under it.
---
--- Nothing here touches a window, a buffer or a debug session, so every
--- function is unit-testable on its own (TESTS/wkddap/memory/format_spec.lua).
---
--- Addresses shown are Lua numbers (doubles): exact up to 2^53, which covers
--- every user-space address of the common 64-bit ABIs (47/48 bits). What is
--- sent to the adapter (a memoryReference) stays text (`literal_reference`,
--- `find_reference`), so a larger address is never rounded. The hex
--- formatting below is done by hand rather than with `%x`, which truncates
--- values above 2^31 on plain Lua 5.1.

local encoding = require("lib.lua.strings.encoding")

local M = {}

---Bytes requested per page (one readMemory request).
M.PAGE_SIZE = 256

---Bytes shown per row, by mode. A bits row is four bytes wide so that a row of
---32 binary digits still fits a normal editor width.
---@type table<Dap.MemoryMode, integer>
M.BYTES_PER_ROW = { hex = 16, bits = 4 }

---Width of one byte cell, by mode ("41" vs. "01000001").
---@type table<Dap.MemoryMode, integer>
M.CELL_WIDTH = { hex = 2, bits = 8 }

---Lines above the first data row: the header and the column ruler.
M.HEADER_LINES = 2

---@alias Dap.MemoryMode "hex"|"bits"

---Decode a base64 payload (readMemory's `data`) into a list of byte values.
---@param data string|nil
---@return integer[]
function M.decode(data)
  local bytes = {}
  if type(data) ~= "string" or data == "" then
    return bytes
  end
  local raw = encoding.base64_decode(data)
  for i = 1, #raw do
    bytes[i] = raw:byte(i)
  end
  return bytes
end

---Encode a list of byte values as base64 (writeMemory's `data`).
---@param bytes integer[]
---@return string
function M.encode(bytes)
  local chars = {}
  for i, b in ipairs(bytes) do
    chars[i] = string.char(b)
  end
  return encoding.base64_encode(table.concat(chars))
end

---Largest address a Lua number holds exactly (2^53). An address at or above
---it is never used as a number: it is kept as text (the memoryReference) and
---the view falls back to offsets relative to it.
M.MAX_EXACT_ADDRESS = 2 ^ 53

---Format an integer as lowercase hex digits, zero-padded to `width` digits.
---A negative number gets a leading "-" (never an address the adapter
---reports, but it must not hang the loop below).
---@param n integer
---@param width? integer
---@return string
function M.hex(n, width)
  if n < 0 then
    return "-" .. M.hex(-n, width)
  end
  local digits = {}
  n = math.floor(n)
  repeat
    local d = n % 16
    table.insert(digits, 1, ("0123456789abcdef"):sub(d + 1, d + 1))
    n = math.floor(n / 16)
  until n == 0
  local s = table.concat(digits)
  if width and #s < width then
    s = string.rep("0", width - #s) .. s
  end
  return s
end

---An address in the form GDB's DAP readMemory accepts as a memoryReference
---(`int(memoryReference, 0)`): "0x" plus hex digits.
---@param n integer
---@return string
function M.hex_address(n)
  return "0x" .. M.hex(n)
end

---@internal
---@param digits string
---@param base integer
---@return integer|nil
local function to_number(digits, base)
  local n = 0
  for i = 1, #digits do
    local d = tonumber(digits:sub(i, i), base)
    if not d then
      return nil
    end
    n = n * base + d
  end
  return n
end

---Parse a literal address: "0x1f40" (any case) or plain decimal digits.
---Anything else -- a variable, `&x`, an expression -- returns nil and has to
---be resolved by the debug adapter instead.
---@param text string|nil
---@return integer|nil
function M.parse_address(text)
  if type(text) ~= "string" then
    return nil
  end
  text = vim.trim(text)
  local hex = text:match("^0[xX](%x+)$")
  if hex then
    return to_number(hex:lower(), 16)
  end
  if text:match("^%d+$") then
    return to_number(text, 10)
  end
  return nil
end

---`n` when it is an address a Lua number holds exactly, else nil.
---@param n integer|nil
---@return integer|nil
function M.exact_address(n)
  if n and n >= 0 and n < M.MAX_EXACT_ADDRESS then
    return n
  end
  return nil
end

---Bytes per context row: a hex row. Rows above the target are counted in
---these, and a known address is aligned to them (a multiple of the bits row
---width too, so bits rows stay aligned as well).
M.CONTEXT_ROW = 16

---Offset (relative to the target, <= 0) of the first page the view reads when
---it opens or jumps, so that `rows` rows of context are shown above the target
---(the way Visual Studio's memory window opens).
---
---With the target's exact address `addr`, the page starts `rows` rows before
---the target's own row: on a 16-byte boundary, never below address 0. Without
---it (an opaque memoryReference, an address above 2^53) the page starts
---exactly `rows * 16` bytes before the target. `rows` is floored and taken as
---0 when it is not a positive number; 0 rows is offset 0 (the target is the
---first byte, not aligned).
---@param addr integer|nil the target's exact address, see `exact_address`
---@param rows integer|nil
---@return integer offset
function M.context_offset(addr, rows)
  rows = type(rows) == "number" and rows == rows and math.max(math.floor(rows), 0) or 0
  local back = rows * M.CONTEXT_ROW
  if back == 0 then
    return 0 -- no context: the target is the first byte, unaligned
  end
  if not addr then
    return -back
  end
  local start = math.floor((addr - back) / M.CONTEXT_ROW) * M.CONTEXT_ROW
  return math.max(start, 0) - addr
end

---Decimal digits as hex digits, by long division on the digit string: exact
---at any length, unlike a round trip through a Lua number.
---@internal
---@param digits string
---@return string
local function decimal_to_hex(digits)
  local out = {}
  digits = digits:gsub("^0+", "")
  while digits ~= "" do
    local quotient, rem = {}, 0
    for i = 1, #digits do
      local cur = rem * 10 + tonumber(digits:sub(i, i))
      local q = math.floor(cur / 16)
      if #quotient > 0 or q > 0 then
        quotient[#quotient + 1] = tostring(q)
      end
      rem = cur % 16
    end
    table.insert(out, 1, ("0123456789abcdef"):sub(rem + 1, rem + 1))
    digits = table.concat(quotient)
  end
  return #out > 0 and table.concat(out) or "0"
end

---The memoryReference for a literal address, or nil when `text` is not one
---(see `parse_address`). A hex literal is sent as typed; a decimal one is
---converted to "0x..." exactly. Neither goes through a Lua number, so an
---address above 2^53 (an ARM64 tagged pointer, a kernel-half address) is not
---rounded.
---@param text string|nil
---@return string|nil
function M.literal_reference(text)
  if type(text) ~= "string" then
    return nil
  end
  text = vim.trim(text)
  if text:match("^0[xX]%x+$") then
    return text
  end
  if text:match("^%d+$") then
    return "0x" .. decimal_to_hex(text)
  end
  return nil
end

---The first "0x..." number anywhere in `text` -- how an evaluate result such
---as `(int *) 0x7ffe0010` or `0x404010 <buffer>` names its address.
---@param text string|nil
---@return integer|nil
function M.find_address(text)
  if type(text) ~= "string" then
    return nil
  end
  local hex = text:match("0[xX](%x+)")
  return hex and to_number(hex:lower(), 16) or nil
end

---Like `find_address`, but as a memoryReference ("0x" plus the digits as
---found), so a 64-bit address is not rounded on the way.
---@param text string|nil
---@return string|nil
function M.find_reference(text)
  if type(text) ~= "string" then
    return nil
  end
  local hex = text:match("0[xX](%x+)")
  return hex and ("0x" .. hex:lower()) or nil
end

---Parse what the user typed for one byte. Accepted: hex digits ("41", "0x41"),
---binary ("0b01000001", or a bare run of up to eight 0/1 digits in bits mode),
---decimal with a "d" prefix ("d65"), and a quoted character ("'A'").
---@param text string|nil
---@param mode Dap.MemoryMode
---@return integer|nil value
---@return string|nil err
function M.parse_byte(text, mode)
  if type(text) ~= "string" then
    return nil, "no value"
  end
  local s = vim.trim(text)
  local value
  local char = s:match("^'(.)'$")
  if char then
    value = char:byte()
  elseif s:match("^0[xX]%x%x?$") then
    value = to_number(s:sub(3):lower(), 16)
  elseif s:match("^0[bB][01]+$") then
    value = to_number(s:sub(3), 2)
  elseif s:match("^[dD]%d+$") then
    value = to_number(s:sub(2), 10)
  elseif mode == "bits" and s:match("^[01]+$") and #s <= 8 then
    value = to_number(s, 2)
  elseif s:match("^%x%x?$") then
    value = to_number(s:lower(), 16)
  end
  if not value then
    return nil, ("not a byte value: %q"):format(s)
  end
  if value > 255 then
    return nil, ("out of range (0..255): %q"):format(s)
  end
  return value
end

---A byte as eight binary digits, most significant bit first.
---@param v integer
---@return string
function M.bits(v)
  local out = {}
  for b = 7, 0, -1 do
    out[#out + 1] = tostring(math.floor(v / 2 ^ b) % 2)
  end
  return table.concat(out)
end

---`v` with bit `bit` flipped; `bit` counts from the left of the displayed
---digits, so 0 is the most significant bit (MSB-first, as rendered).
---@param v integer
---@param bit integer 0..7
---@return integer
function M.toggle_bit(v, bit)
  local mask = 2 ^ (7 - bit)
  if math.floor(v / mask) % 2 == 1 then
    return v - mask
  end
  return v + mask
end

---@internal
---@param v integer|nil
---@return string
local function printable(v)
  if v and v >= 0x20 and v < 0x7f then
    return string.char(v)
  end
  return "."
end

---Human-readable message of a DAP error response (nvim-dap hands over
---`{ message = ..., body = { error = { format = ... } } }`), or of anything
---else that arrives in its place. Always ONE line: the message becomes a
---buffer line of the view (`nvim_buf_set_lines` refuses a newline, and so
---does the companion's `update`), and `vim.inspect` of a table is many.
---@param err any
---@return string
function M.error_message(err)
  local text
  if type(err) == "table" then
    local body_err = type(err.body) == "table" and err.body.error or nil
    if type(body_err) == "table" and type(body_err.format) == "string" then
      text = body_err.format
    elseif type(err.message) == "string" and err.message ~= "" then
      text = err.message
    else
      text = vim.inspect(err)
    end
  else
    text = tostring(err)
  end
  return (text:gsub("%s*\r?\n%s*", " "))
end

---@class Dap.MemoryLayout
---@field mode Dap.MemoryMode
---@field per_row integer bytes per row
---@field addr_width integer width of the address column, in characters
---@field cells integer[] 0-based start column of each byte cell in a row
---@field cell_width integer
---@field ascii_start integer 0-based column of the first ASCII character
---@field width integer total width of a data row

---Column layout of a data row.
---@param mode Dap.MemoryMode
---@param addr_width integer
---@return Dap.MemoryLayout
function M.layout(mode, addr_width)
  local per_row = M.BYTES_PER_ROW[mode]
  local cell_width = M.CELL_WIDTH[mode]
  local cells = {}
  local col = addr_width + 2
  for j = 1, per_row do
    if j > 1 then
      col = col + 1
    end
    -- Hex rows get an extra gap between the two halves, like every hex
    -- editor; bits rows are already one byte per group.
    if mode == "hex" and j == 9 then
      col = col + 1
    end
    cells[j] = col
    col = col + cell_width
  end
  local ascii_start = col + 3 -- "  |"
  return {
    mode = mode,
    per_row = per_row,
    addr_width = addr_width,
    cells = cells,
    cell_width = cell_width,
    ascii_start = ascii_start,
    width = ascii_start + per_row + 1,
  }
end

---Which byte of the row (1-based) sits at 0-based column `col`, and which bit
---of it in bits mode (0 = most significant). The ASCII column maps to its byte
---too (no bit). nil when the column holds no byte.
---@param layout Dap.MemoryLayout
---@param col integer
---@return integer|nil index
---@return integer|nil bit
function M.column_to_byte(layout, col)
  for j, start in ipairs(layout.cells) do
    if col >= start and col < start + layout.cell_width then
      if layout.mode == "bits" then
        return j, col - start
      end
      return j, nil
    end
  end
  if col >= layout.ascii_start and col < layout.ascii_start + layout.per_row then
    return col - layout.ascii_start + 1, nil
  end
  return nil, nil
end

---@class Dap.MemoryPage
---@field label string what the user asked for ("&buffer", "0x404010")
---@field mode Dap.MemoryMode
---@field offset integer page start, relative to the base memoryReference
---@field count integer bytes requested
---@field bytes integer[] bytes read (may be shorter than `count`)
---@field address integer|nil address of the first byte, if known
---@field unreadable? integer readMemory's `unreadableBytes`
---@field error? string the last readMemory failure, if the page has none
---@field stale? boolean the session behind the view has ended
---@field written? table<integer, boolean> page indices written by this view (undo-able)
---@field target? integer page index of the target byte (offset 0), when on this page

---Highlight group of the target byte (linked to `Search` by the view).
M.TARGET_GROUP = "WkddapMemoryTarget"

---Extmark priority of the target highlight: below the default (4096) of the
---other cell highlights, so a written byte's `DiffText` wins where both set
---the same attribute. The target's ASCII character is marked too, so the
---target stays visible either way.
M.TARGET_PRIORITY = 4000

---@class Dap.MemoryHighlight
---@field line integer 0-based
---@field col_start integer 0-based, inclusive
---@field col_end integer 0-based, exclusive
---@field group string
---@field priority? integer extmark priority (default: Neovim's)

---@class Dap.MemoryRender
---@field lines string[]
---@field layout Dap.MemoryLayout
---@field first_row integer 1-based buffer line of the first data row
---@field rows integer number of data rows
---@field highlights Dap.MemoryHighlight[]

---@internal
---@param n integer
---@return string
local function signed_hex(n)
  if n < 0 then
    return "-0x" .. M.hex(-n)
  end
  return "+0x" .. M.hex(n)
end

---Render one page into buffer lines plus everything the view needs to map
---the cursor back to a byte and to highlight cells.
---@param page Dap.MemoryPage
---@return Dap.MemoryRender
function M.render(page)
  local mode = page.mode
  local per_row = M.BYTES_PER_ROW[mode]
  local rows = math.ceil(page.count / per_row)

  -- Address column: absolute when the adapter told us where the page is,
  -- otherwise relative to the base reference (an opaque memoryReference).
  local function row_address(r)
    if page.address then
      return "0x" .. M.hex(page.address + (r - 1) * per_row, 0)
    end
    return signed_hex(page.offset + (r - 1) * per_row)
  end
  local addr_width = #row_address(rows)
  if page.address then
    addr_width = math.max(addr_width, 10) -- "0x" + at least 8 digits
  end
  local function padded_address(r)
    local s = row_address(r)
    if page.address then
      return "0x" .. M.hex(page.address + (r - 1) * per_row, addr_width - 2)
    end
    return string.rep(" ", addr_width - #s) .. s
  end

  local layout = M.layout(mode, addr_width)
  local lines, highlights = {}, {}

  local where = page.address and ("0x" .. M.hex(page.address)) or "?"
  local header = ("%s  @ %s  (%s)  [%s]"):format(page.label, where, signed_hex(page.offset), mode)
  if page.unreadable and page.unreadable > 0 then
    header = header .. ("  %d unreadable"):format(page.unreadable)
  end
  if page.stale then
    header = header .. "  [stale: session ended]"
  end
  lines[1] = header
  highlights[#highlights + 1] = {
    line = 0,
    col_start = 0,
    col_end = #header,
    group = page.stale and "WarningMsg" or "Title",
  }

  -- Ruler: the byte's offset within the row in hex mode, the bit numbers
  -- (7 = MSB .. 0 = LSB) in bits mode.
  local ruler = { string.rep(" ", addr_width + 2) }
  for j = 1, per_row do
    local label = mode == "bits" and "76543210" or M.hex(j - 1, 2)
    local start = layout.cells[j]
    local current = #table.concat(ruler)
    ruler[#ruler + 1] = string.rep(" ", start - current) .. label
  end
  lines[2] = table.concat(ruler)
  highlights[#highlights + 1] = { line = 1, col_start = 0, col_end = #lines[2], group = "Comment" }

  local first_row = M.HEADER_LINES + 1
  if page.error and #page.bytes == 0 then
    lines[#lines + 1] = "readMemory failed: " .. page.error
    highlights[#highlights + 1] =
      { line = #lines - 1, col_start = 0, col_end = #lines[#lines], group = "ErrorMsg" }
    return {
      lines = lines,
      layout = layout,
      first_row = first_row,
      rows = 0,
      highlights = highlights,
    }
  end

  local missing = mode == "bits" and "????????" or "??"
  for r = 1, rows do
    local parts = { padded_address(r), "  " }
    local ascii = {}
    local line_nr = #lines -- 0-based index of the row about to be added
    for j = 1, per_row do
      local index = (r - 1) * per_row + j
      local v = page.bytes[index]
      local cell
      if index > page.count then
        cell = string.rep(" ", layout.cell_width)
      elseif v == nil then
        cell = missing
      elseif mode == "bits" then
        cell = M.bits(v)
      else
        cell = M.hex(v, 2)
      end
      local start = layout.cells[j]
      local current = #table.concat(parts)
      parts[#parts + 1] = string.rep(" ", start - current) .. cell
      ascii[j] = index <= page.count and printable(v) or " "

      local group
      if index <= page.count and v == nil then
        group = "Comment"
      elseif page.written and page.written[index] then
        group = "DiffText"
      end
      if group then
        highlights[#highlights + 1] = {
          line = line_nr,
          col_start = start,
          col_end = start + layout.cell_width,
          group = group,
        }
      end
      if page.target == index and index <= page.count then
        local ascii_col = layout.ascii_start + j - 1
        for _, cols in ipairs({ { start, start + layout.cell_width }, { ascii_col, ascii_col + 1 } }) do
          highlights[#highlights + 1] = {
            line = line_nr,
            col_start = cols[1],
            col_end = cols[2],
            group = M.TARGET_GROUP,
            priority = M.TARGET_PRIORITY,
          }
        end
      end
    end
    parts[#parts + 1] = "  |" .. table.concat(ascii) .. "|"
    lines[#lines + 1] = table.concat(parts)
    highlights[#highlights + 1] =
      { line = line_nr, col_start = 0, col_end = addr_width, group = "LineNr" }
  end

  return {
    lines = lines,
    layout = layout,
    first_row = first_row,
    rows = rows,
    highlights = highlights,
  }
end

---Which byte of the page (1-based) is at buffer position `lnum` (1-based) /
---`col` (0-based), plus the bit in bits mode. nil outside the data rows.
---@param render Dap.MemoryRender
---@param lnum integer
---@param col integer
---@return integer|nil index
---@return integer|nil bit
function M.position_to_byte(render, lnum, col)
  local r = lnum - render.first_row + 1
  if r < 1 or r > render.rows then
    return nil, nil
  end
  local j, bit = M.column_to_byte(render.layout, col)
  if not j then
    return nil, nil
  end
  return (r - 1) * render.layout.per_row + j, bit
end

---Buffer position (1-based line, 0-based column) of byte `index` of the page:
---the inverse of `position_to_byte`, used to keep the cursor on an edited
---byte across a re-render.
---@param render Dap.MemoryRender
---@param index integer
---@return integer lnum
---@return integer col
function M.byte_to_position(render, index)
  local per_row = render.layout.per_row
  local r = math.floor((index - 1) / per_row) + 1
  local j = (index - 1) % per_row + 1
  return render.first_row + r - 1, render.layout.cells[j]
end

return M
