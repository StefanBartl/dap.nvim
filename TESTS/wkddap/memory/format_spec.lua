--- Covers wkddap.memory.format: the pure helpers of the memory view (base64,
--- address/byte parsing, the hex/bits page layout and the cursor -> byte map).

local format = require("wkddap.memory.format")

describe("wkddap.memory.format base64", function()
  it("decodes readMemory data into byte values", function()
    assert.are.same({ 0x41, 0x42, 0x43 }, format.decode("QUJD"))
    assert.are.same({ 0x00, 0xff }, format.decode("AP8="))
    assert.are.same({}, format.decode(""))
    assert.are.same({}, format.decode(nil))
  end)

  it("encodes byte values for writeMemory and round-trips", function()
    assert.are.equal("QUJD", format.encode({ 0x41, 0x42, 0x43 }))
    assert.are.equal("/w==", format.encode({ 0xff }))
    local all = {}
    for i = 0, 255 do
      all[#all + 1] = i
    end
    assert.are.same(all, format.decode(format.encode(all)))
  end)
end)

describe("wkddap.memory.format context_offset", function()
  it("starts the page context rows above the target's row, 16-byte aligned", function()
    assert.are.equal(-64, format.context_offset(0x404010, 4))
    assert.are.equal(-67, format.context_offset(0x404013, 4)) -- page at 0x403fd0
    assert.are.equal(-79, format.context_offset(0x40401f, 4))
    assert.are.equal(-16, format.context_offset(0x404010, 1))
    assert.are.equal(-240, format.context_offset(0x404010, 15))
    for _, addr in ipairs({ 0x404010, 0x404013, 0x7ffe0001 }) do
      assert.are.equal(0, (addr + format.context_offset(addr, 4)) % 16)
    end
  end)

  it("never starts below address 0", function()
    assert.are.equal(0, format.context_offset(0, 4))
    assert.are.equal(-0x10, format.context_offset(0x10, 4))
    assert.are.equal(-0x3f, format.context_offset(0x3f, 4))
    assert.are.equal(-0x40, format.context_offset(0x40, 4))
    assert.are.equal(-0x41, format.context_offset(0x41, 4)) -- row 0 is all that fits
    assert.are.equal(-0x40, format.context_offset(0x50, 4))
  end)

  it("goes back exactly rows * 16 bytes when the address is unknown", function()
    assert.are.equal(-64, format.context_offset(nil, 4))
    assert.are.equal(-16, format.context_offset(nil, 1))
  end)

  it("treats 0, negative, fractional and non-number rows sanely", function()
    assert.are.equal(0, format.context_offset(0x404013, 0))
    assert.are.equal(0, format.context_offset(nil, 0))
    assert.are.equal(0, format.context_offset(0x404013, -3))
    assert.are.equal(0, format.context_offset(nil, nil))
    assert.are.equal(0, format.context_offset(0x404010, 0 / 0))
    assert.are.equal(-32, format.context_offset(nil, 2.7))
  end)
end)

describe("wkddap.memory.format target highlight", function()
  ---@param page table
  local function target_hls(page)
    local r = format.render(page)
    return vim.tbl_filter(function(hl)
      return hl.group == format.TARGET_GROUP
    end, r.highlights),
      r
  end

  it("marks the target cell and its ASCII character, below DiffText's priority", function()
    local hls, r = target_hls({
      label = "x",
      mode = "hex",
      offset = -64,
      count = 256,
      bytes = { 0x41 },
      address = 0x403fd0,
      target = 65,
      written = { [65] = true },
    })
    assert.are.equal(2, #hls)
    assert.are.same({ 6, r.layout.cells[1], r.layout.cells[1] + 2 }, {
      hls[1].line,
      hls[1].col_start,
      hls[1].col_end,
    })
    assert.are.same({ 6, r.layout.ascii_start }, { hls[2].line, hls[2].col_start })
    assert.is_true(hls[1].priority < 4096)
  end)

  it("marks nothing without a target on the page", function()
    local hls = target_hls({ label = "x", mode = "bits", offset = 0, count = 256, bytes = {} })
    assert.are.same({}, hls)
  end)
end)

describe("wkddap.memory.format addresses", function()
  it("formats hex beyond 32 bits", function()
    assert.are.equal("7ffe12345678", format.hex(0x7ffe12345678))
    assert.are.equal("00ff", format.hex(255, 4))
    assert.are.equal("0", format.hex(0))
    assert.are.equal("0x401000", format.hex_address(0x401000))
  end)

  it("formats a negative number instead of looping forever", function()
    assert.are.equal("-f0", format.hex(-240))
    assert.are.equal("-01", format.hex(-1, 2))
  end)

  it("keeps literal references exact, even above 2^53", function()
    assert.are.equal("0xb4000078a1c3e011", format.literal_reference(" 0xb4000078a1c3e011 "))
    assert.are.equal("0X1F", format.literal_reference("0X1F"))
    assert.are.equal("0x1000", format.literal_reference("4096"))
    assert.are.equal("0x0", format.literal_reference("000"))
    assert.are.equal("0xffffffffffffffff", format.literal_reference("18446744073709551615"))
    assert.is_nil(format.literal_reference("&buffer"))
    assert.is_nil(format.literal_reference("0x"))
    assert.is_nil(format.literal_reference(nil))
    assert.are.equal("0xb4000078a1c3e011", format.find_reference("(int *) 0xB4000078A1C3E011"))
    assert.is_nil(format.find_reference("42"))
  end)

  it("treats an address as a number only while it is exact", function()
    assert.are.equal(0x404010, format.exact_address(0x404010))
    assert.is_nil(format.exact_address(2 ^ 53))
    assert.is_nil(format.exact_address(-240))
    assert.is_nil(format.exact_address(nil))
  end)

  it("parses literal addresses only", function()
    assert.are.equal(0x401000, format.parse_address("0x401000"))
    assert.are.equal(0x7FFE0010, format.parse_address(" 0X7FFE0010 "))
    assert.are.equal(4096, format.parse_address("4096"))
    assert.is_nil(format.parse_address("&buffer"))
    assert.is_nil(format.parse_address("ptr + 4"))
    assert.is_nil(format.parse_address("0x"))
    assert.is_nil(format.parse_address(nil))
  end)

  it("finds the address inside an evaluate result", function()
    assert.are.equal(0x7ffe0010, format.find_address("(int *) 0x7ffe0010"))
    assert.are.equal(0x404010, format.find_address("0x404010 <buffer>"))
    assert.is_nil(format.find_address("42"))
  end)
end)

describe("wkddap.memory.format.parse_byte", function()
  it("accepts hex, 0x, 0b, d-decimal and a quoted char", function()
    assert.are.equal(0x41, format.parse_byte("41", "hex"))
    assert.are.equal(0x0f, format.parse_byte("f", "hex"))
    assert.are.equal(0xab, format.parse_byte("0xAB", "hex"))
    assert.are.equal(5, format.parse_byte("0b101", "hex"))
    assert.are.equal(65, format.parse_byte("d65", "hex"))
    assert.are.equal(65, format.parse_byte("'A'", "hex"))
  end)

  it("reads a bare 0/1 run as binary in bits mode, as hex in hex mode", function()
    assert.are.equal(0x41, format.parse_byte("01000001", "bits"))
    assert.are.equal(0x10, format.parse_byte("10", "hex"))
    assert.are.equal(2, format.parse_byte("10", "bits"))
  end)

  it("rejects what is not one byte", function()
    local v, err = format.parse_byte("zz", "hex")
    assert.is_nil(v)
    assert.truthy(err:find("not a byte value"))
    v, err = format.parse_byte("d300", "hex")
    assert.is_nil(v)
    assert.truthy(err:find("out of range"))
    assert.is_nil((format.parse_byte("123", "hex")))
  end)
end)

describe("wkddap.memory.format bits", function()
  it("renders MSB first and flips by display position", function()
    assert.are.equal("01000001", format.bits(0x41))
    assert.are.equal(0xc1, format.toggle_bit(0x41, 0)) -- MSB
    assert.are.equal(0x40, format.toggle_bit(0x41, 7)) -- LSB
    assert.are.equal(0x41, format.toggle_bit(format.toggle_bit(0x41, 3), 3))
  end)
end)

describe("wkddap.memory.format.error_message", function()
  it("prefers the DAP error body, then message", function()
    assert.are.equal(
      "Cannot access memory",
      format.error_message({ message = "x", body = { error = { format = "Cannot access memory" } } })
    )
    assert.are.equal("Out of memory", format.error_message({ message = "Out of memory" }))
    assert.are.equal("boom", format.error_message("boom"))
  end)

  it("is always one line (it becomes a buffer line)", function()
    -- A table without message/format is shown as vim.inspect: many lines.
    local text = format.error_message({ code = 1, data = { a = 1, b = 2 } })
    assert.is_nil(text:find("\n", 1, true))
    assert.truthy(text:find("code = 1", 1, true))
    assert.are.equal("first second", format.error_message("first\n  second"))
    assert.are.equal("a b", format.error_message({ message = "a\r\nb" }))
  end)
end)

---@param n integer
---@param start? integer
---@return integer[]
local function seq(n, start)
  local out = {}
  for i = 1, n do
    out[i] = ((start or 0) + i - 1) % 256
  end
  return out
end

describe("wkddap.memory.format.render", function()
  local function page(over)
    return vim.tbl_extend("force", {
      label = "&buffer",
      mode = "hex",
      offset = 0,
      count = 32,
      bytes = seq(32, 0x41),
      address = 0x404010,
    }, over or {})
  end

  it("renders hex rows with address and ASCII columns", function()
    local r = format.render(page())
    assert.are.equal("&buffer  @ 0x404010  (+0x0)  [hex]", r.lines[1])
    assert.are.equal(
      "0x00404010  41 42 43 44 45 46 47 48  49 4a 4b 4c 4d 4e 4f 50  |ABCDEFGHIJKLMNOP|",
      r.lines[3]
    )
    assert.are.equal(
      "0x00404020  51 52 53 54 55 56 57 58  59 5a 5b 5c 5d 5e 5f 60  |QRSTUVWXYZ[\\]^_`|",
      r.lines[4]
    )
    assert.are.equal(3, r.first_row)
    assert.are.equal(2, r.rows)
    assert.truthy(r.lines[2]:find("00 01 02 03 04 05 06 07  08 09", 1, true))
  end)

  it("renders bits rows MSB-first, four bytes per row", function()
    local r = format.render(page({ mode = "bits", count = 8, bytes = { 0x41, 0x00, 0xff, 0x80 } }))
    assert.are.equal("0x00404010  01000001 00000000 11111111 10000000  |A...|", r.lines[3])
    assert.are.equal("0x00404014  ???????? ???????? ???????? ????????  |....|", r.lines[4])
    assert.truthy(r.lines[2]:find("76543210 76543210", 1, true))
  end)

  it("shows missing (unreadable) bytes as ?? and says how many", function()
    local r = format.render(page({ count = 16, bytes = seq(4, 0x30), unreadable = 12 }))
    assert.truthy(r.lines[1]:find("12 unreadable", 1, true))
    assert.are.equal(
      "0x00404010  30 31 32 33 ?? ?? ?? ??  ?? ?? ?? ?? ?? ?? ?? ??  |0123............|",
      r.lines[3]
    )
  end)

  it("falls back to offsets relative to the base without an address", function()
    local r = format.render(page({ address = false, offset = -16, count = 16 }))
    assert.truthy(r.lines[1]:find("@ ?  (-0x10)", 1, true))
    assert.truthy(vim.startswith(r.lines[3], "-0x10  41 42"))
  end)

  it("renders a read error instead of rows", function()
    local r = format.render(page({ bytes = {}, error = "Cannot access memory at 0x0" }))
    assert.are.equal("readMemory failed: Cannot access memory at 0x0", r.lines[3])
    assert.are.equal(0, r.rows)
  end)

  it("marks a stale page in the header", function()
    local r = format.render(page({ stale = true }))
    assert.truthy(r.lines[1]:find("[stale: session ended]", 1, true))
  end)

  it("highlights written bytes", function()
    local r = format.render(page({ written = { [2] = true } }))
    local found = false
    for _, hl in ipairs(r.highlights) do
      if hl.group == "DiffText" and hl.line == 2 and hl.col_start == 15 and hl.col_end == 17 then
        found = true
      end
    end
    assert.is_true(found)
  end)
end)

describe("wkddap.memory.format cursor mapping", function()
  it("maps hex cells and ASCII characters back to their byte", function()
    local r = format.render({
      label = "x",
      mode = "hex",
      offset = 0,
      count = 32,
      bytes = seq(32),
      address = 0x1000,
    })
    -- Row 1 ("0x00001000  00 01 ..."): first cell at column 12.
    assert.are.equal(1, (format.position_to_byte(r, 3, 12)))
    assert.are.equal(1, (format.position_to_byte(r, 3, 13)))
    assert.is_nil((format.position_to_byte(r, 3, 14))) -- the gap
    assert.are.equal(9, (format.position_to_byte(r, 3, r.layout.cells[9])))
    assert.are.equal(17 + 4, (format.position_to_byte(r, 4, r.layout.ascii_start + 4)))
    assert.is_nil((format.position_to_byte(r, 1, 12))) -- header
    assert.is_nil((format.position_to_byte(r, 3, 0))) -- address column

    local lnum, col = format.byte_to_position(r, 18)
    assert.are.equal(4, lnum)
    assert.are.equal(r.layout.cells[2], col)
  end)

  it("reports the bit under the cursor in bits mode (0 = MSB)", function()
    local r = format.render({
      label = "x",
      mode = "bits",
      offset = 0,
      count = 8,
      bytes = seq(8),
      address = 0x1000,
    })
    local start = r.layout.cells[2]
    local index, bit = format.position_to_byte(r, 3, start)
    assert.are.equal(2, index)
    assert.are.equal(0, bit)
    index, bit = format.position_to_byte(r, 4, r.layout.cells[1] + 7)
    assert.are.equal(5, index)
    assert.are.equal(7, bit)
  end)
end)
