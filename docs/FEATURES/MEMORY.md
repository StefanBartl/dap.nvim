# Memory view

A Visual-Studio-style memory window for the session that is already running:
a hex (or bit) dump of an address range, editable byte by byte, in a float of
the same Neovim. It talks DAP `readMemory` / `writeMemory` through the
nvim-dap session you are debugging — no `/proc/<pid>/mem`. Optionally the
same view opens read-only in a [companion window](#companion-window-second-monitor)
(a second Neovim in its own terminal) for a second monitor.

- **Module:** `lua/wkddap/memory/init.lua` (session checks, requests, undo,
  listeners), `memory/format.lua` (pure: base64, parsing, page layout),
  `memory/view.lua` (the float and its keys), `memory/companion.lua` (the
  same view in a companion window)
- **Keymap:** `<leader>dm` (action `memory_view`, prompts for the target),
  `<leader>dM` (`memory_window`: the companion window)
- **Usercmd:** `:Dap memory [address-or-expression]`,
  `:Dap memory-window [address-or-expression]`

## Opening it

```vim
:Dap memory &buffer        " an expression the adapter evaluates to an address
:Dap memory ptr            " a pointer variable: its value is the address
:Dap memory 0x404010       " a literal address (hex, or plain decimal)
:Dap memory                " prompts (pre-filled with &<word under cursor>)
```

A literal hex address is sent as is (a decimal one as the exact same number
in `0x…` form). Anything else goes to the adapter as an
`evaluate` request in the current frame. Like Visual Studio's memory window,
a value that is an address (`ptr` evaluating to `0x7ff6…`) is where the view
looks; otherwise the result's `memoryReference` is used (an array, `&buffer`
under GDB), or — for adapters that set none — the first `0x…` in the result
(as text, so a 64-bit address is not rounded). The value comes first because
adapters disagree on a pointer's `memoryReference`: GDB gives where it
points, lldb-dap where the pointer itself is stored. codelldb shows a
pointer to characters as the string it points to (`&buffer` → `"ABC…"`)
and sets no `memoryReference`; for a pointer type the view then asks once
more with codelldb's `,x` format specifier (`&buffer,x` → `0x7ff6…`). A
value that is no address (`n` evaluating to `42`) is refused with a hint to
try `&n`.

The view keeps the resolved **base reference** and an **offset**: paging only
moves the offset (it may go negative, but not below address 0 when the base
is a known address), so a page is always
`readMemory { memoryReference = base, offset = offset, count = 256 }` and the
target itself is always offset 0. The header shows the target, the address
the adapter reported for the page start (`response.address`) and the offset.

## Context rows (target not on the first row)

Like Visual Studio's memory window, the view does not open with the target
as its first row: it shows `memory.context_rows` rows (default **4**, 16
bytes each; see [configuration](../configuration.md)) **above** the target,
and puts the cursor on the target byte. The same applies to a jump with `a`.

- **Known address** (a literal, or an expression that resolved to one): the
  page starts on the 16-byte row `context_rows` rows above the target's own
  row, so rows stay aligned (`0x404013` → page at `0x403fd0`, offset
  `-0x43`). It never starts below address 0 (`0x20` → page at `0x0`).
- **Unknown address** (an opaque `memoryReference`, an address above 2^53):
  the page starts exactly `context_rows * 16` bytes before the target.
- **The context read does not reach the target.** Memory before the target
  may be unmapped (the target starts a mapping, e.g. the image header): GDB
  fails the whole read, lldb-dap and codelldb answer it with success but no
  byte at all (`data` is contiguous from the page start, the rest is
  `unreadableBytes`). codelldb also stops at a **region boundary** even when
  the next region is readable (`&buffer` 64 bytes above a region start: 32
  bytes and 224 "unreadable", while a read from the boundary gets all 256).
  So when the first read stops before the target, the view reads **once
  more**: from where the first read stopped, rounded up to a row (the
  context rows it got stay), or from the target itself when it got nothing.
  If that second read gets nothing either, the target really is unreadable
  and the first page is shown, with `??` at the target. A refresh or an
  `event_stopped`/`event_memory` re-read while that first read is still
  pending keeps the fallback (and the cursor move); re-reads of a page that
  was already shown (paging, refresh, re-reads after an edit) are never
  retried.
- The cursor moves to the target only when the read of the open/jump answers;
  paging, refresh and edits keep the cursor on the byte it is on.
- The **target byte** (its cell and its ASCII character) is highlighted with
  `WkddapMemoryTarget` (a default link to `Search`) whenever it is on the
  shown page. A written byte's `DiffText` has the higher priority; the
  ASCII mark keeps the target visible either way.

`context_rows = 0` restores the plain behaviour: the page starts exactly at
the target. The arithmetic is `format.context_offset(addr, rows)` (pure, unit
tested).

Requests are answered asynchronously. The view switches to a new page (after
`n`, `p`, `a`) only when that page's read answers; until then it keeps showing
the old one, and an edit is refused ("the page is still being read") rather
than applied to the wrong page. Only the newest read is ever shown.

## Layout

```text
&buffer  @ 0x7ff7821e8fc0  (-0x40)  [hex]
                00 01 02 03 04 05 06 07  08 09 0a 0b 0c 0d 0e 0f
0x7ff7821e8fc0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
0x7ff7821e8fd0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
0x7ff7821e8fe0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
0x7ff7821e8ff0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
0x7ff7821e9000  41 42 43 44 45 46 47 48  49 4a 4b 4c 4d 4e 4f 50  |ABCDEFGHIJKLMNOP|
```

(`&buffer` is at `0x7ff7821e9000`: four context rows above it, the cursor on
its first byte, `41`.)

```text
&buffer  @ 0x7ff7821e8fc0  (-0x40)  [bits]
                76543210 76543210 76543210 76543210
...
0x7ff7821e8ffc  00000000 00000000 00000000 00000000  |....|
0x7ff7821e9000  01000001 01000010 11000011 01000100  |AB.D|
```

Hex mode: 16 bytes per row, address column, ASCII column. Bits mode: 4 bytes
per row, each byte as eight bits **MSB first** (the ruler numbers them 7..0).
Bytes are shown in **memory order** — no endianness is applied; a 32-bit
integer on x86 reads backwards, exactly as in Visual Studio's byte view.

Bytes the adapter could not read (`unreadableBytes`, or a short `data`) are
`??` and counted in the header. A failed `readMemory` (an error response, for
example GDB's `Cannot access memory at address 0x0`) shows its message in
place of the rows and as a warning — never a traceback.

## Keys (in the view)

| Key | Action |
| --- | --- |
| `e` / `<CR>` | Edit the byte under the cursor (prompt, pre-filled with its value) |
| `<2-LeftMouse>` | Double-click: edit that byte; in bits mode flip that bit |
| `<Space>` | Bits mode: flip the bit under the cursor |
| `u` | Undo the last write of this view |
| `b` | Toggle hex / bits |
| `a` | Go to another address or expression (prompt) |
| `n` / `<PageDown>` | Next page (256 bytes) |
| `p` / `<PageUp>` | Previous page |
| `r` | Refresh (re-read the page) |
| `q` / `<Esc>` | Close |

The edit prompt accepts `41`, `0x41`, `0b01000001`, `d65` (decimal) and
`'A'`; in bits mode a bare run of 0/1 (`01000001`) is binary.

## Companion window (second monitor)

`:Dap memory-window &buffer` (or `<leader>dM`, or
`require("wkddap.memory").open("&buffer", { companion = true })`) shows the
view in a **companion window** instead of the float: a second Neovim in its
own terminal window, opened by
[`lib.nvim.companion`](https://github.com/WKDSteve/lib.nvim) (Windows
Terminal on Windows, `$TERMINAL` or the usual terminals on Linux, Terminal.app
or `$TERMINAL` on macOS), that connects back over msgpack-RPC. Drag it to the
second monitor and keep debugging in the first.

- **Same page, same layout.** The companion gets exactly the lines and
  highlights `format.render` produces for the float (header, ruler, rows,
  target and written-byte highlights), pushed after every read. Only the
  legend differs: it lists the companion's keys. The companion's own buffer
  is `nofile`, non-modifiable; nothing is typed into it.
- **Navigation from there.** `a` asks for the address or expression *in the
  companion* (`vim.ui.input` there) and sends the text here; `n`/`p` page,
  `b` toggles hex/bits, `r` re-reads, `q` closes the companion (the view is
  gone then, like closing the float). Every key arrives here as a named
  action; the `evaluate`/`readMemory` requests, the state and the listeners
  stay in this instance. The companion never talks to the adapter.
- **Read-only on purpose.** No `e`, `<Space>`, `u` or double-click there:
  `writeMemory` stays in the float. (The API `memory.edit()` still works while
  the companion is open; the companion shows the result.)
- **Session end** is shown like in the float: title `Memory [stale]`, the
  header note, the last page stays readable; reads are refused with the same
  message here. The companion is not closed automatically.
- **One view at a time.** `:Dap memory` while the companion is open replaces
  it with the float; `:Dap memory-window` while the float is open replaces
  the float. A second `:Dap memory-window` (same session) moves the open
  companion, keeping mode and undo stack, as `a` does.
- **No cursor from here.** The cursor lives in the other process: the view
  cannot put it on the target byte, the companion keeps its own cursor line
  across updates. The target byte is highlighted (`Search` there, since the
  companion runs `-u NONE` and has no `WkddapMemoryTarget`).
- **When it cannot open** (no terminal found, no RPC server, the process does
  not start) the error says why; nothing is left behind. A companion whose
  terminal never ran the inner `nvim` is closed by lib.nvim's attach timeout
  (15 s) with a warning.

`scripts/memory-gdb-check.lua` runs this end to end with
`WKDDAP_MEMORY_COMPANION=1` (a real terminal window) or `=headless` (a second
`nvim --headless`, no window); see [Adapters](#adapters).

## Editing, undo, endianness

- **Byte-wise.** Every edit is one `writeMemory` of exactly one byte (base64
  `data`) at `base + offset`. The byte changes in the view as the write is
  sent, so a second edit of the same byte (two quick `<Space>` on one byte)
  builds on the first; when the write answers, the page is re-read — the view
  ends up showing what the adapter reports, not what was typed. Since only
  single bytes are written, **endianness never matters for an edit.**
- **Undo** is the plugin's own stack, not the debuggee's: each successful
  write records `{ reference, offset, old, new }`; `u` writes `old` back the
  same way (and keeps the entry if that write fails). It survives paging and
  jumping (the entry remembers its own location) and lives as long as the
  view. A byte the program changed in between is overwritten by an undo all
  the same. Bytes with an undo entry on the current page are highlighted.
- A write needs `supportsWriteMemoryRequest`; without it the edit is refused
  with a message and nothing is sent.

## Session lifetime

When the view opens it registers nvim-dap listeners under the key
`wkddap.memory`:

- `event_terminated`, `event_exited`, `disconnect` → the view turns **stale**:
  title `Memory [stale]`, a header note, and every read/write/undo is refused
  with "the debug session has ended". The last page stays visible for
  reading. A session nvim-dap closes without these events (the adapter
  process died, its pipe closed, a disconnect timed out) is noticed through
  `session.closed` on the next key and goes stale the same way.
- `event_stopped`, `event_memory` → the page is re-read.

The listeners only react to the view's own session and are removed when the
view closes. Nothing here relies on a global "session active" flag.

## Messages

| Situation | Message |
| --- | --- |
| nvim-dap missing | `Memory view: nvim-dap is not installed.` |
| no session | `Memory view: no debug session is running.` |
| adapter cannot read | `… does not support reading memory (supportsReadMemoryRequest is not set).` |
| adapter cannot write | `… does not support writing memory (supportsWriteMemoryRequest is not set).` |
| read fails | `Memory view: readMemory failed: <adapter message>` (not for the context read of an open/jump, which is retried at the target first) |
| edit while another page is read | `Memory view: the page is still being read; try again in a moment.` |
| `p` below address 0 | `Memory view: there is no page below address 0.` |

## Why a `ui.kit.surface`

The float is a `ui.kit.surface` (themed border/title, `q`/`<Esc>`,
`winfixbuf`, an on-close hook that removes the listeners) — not
`ui.kit.viewer`, which closes as soon as focus leaves it: every edit and jump
opens a `ui.kit.input` prompt, and the view must still be there when the
answer arrives. A hand-rolled scratch float would re-implement what the
surface already does.

## Adapters

Checked against three adapters on Windows, all of which report
`supportsReadMemoryRequest = true` and `supportsWriteMemoryRequest = true`
(a byte written through the view reached the running program in each case):

| adapter | `evaluate` of a pointer | a read that starts before a mapping / region |
|---|---|---|
| **GDB 16.3** (`gdb -i dap`) | `memoryReference` = where it points | error response (the whole read fails) |
| **lldb-dap 22** | `memoryReference` = where the pointer is stored; the value is the address | success, no byte, `unreadableBytes` = all; `address` = the one asked for |
| **codelldb 1.12** | no `memoryReference`; a pointer to characters shows the string, `,x` gives the address | as lldb-dap; also stops at a **region boundary** before readable memory |

None of them shifts `address` to the first readable byte: `address` is
always the page start that was asked for, so the page is never shown
displaced. GDB's server needs the `memoryReference` to be a number
(`int(ref, 0)`), which is why expressions are resolved through `evaluate`
first. Any adapter that advertises the two capabilities works the same way;
one that does not gets the message above.

`scripts/memory-gdb-check.lua` is the manual end-to-end check (not part of
the spec suite): it compiles `scripts/fixtures/memory_target.c`, stops it at
a breakpoint under real nvim-dap + GDB, reads `&buffer` (context rows above
it, row alignment, cursor on `buffer[0]`), writes, re-reads, undoes, flips a
bit, reads an unmapped address, jumps to the start of the executable image
(the context read fails there and is retried at offset 0), and finally writes
a byte the program checks in its exit code.

```bash
nvim --headless -u NONE -l scripts/memory-gdb-check.lua [path/to/nvim-dap]
```

With `WKDDAP_MEMORY_COMPANION=1` it also opens the view in a real companion
window before the final write (waits for the attach, reads the companion's
buffer over RPC, presses `n` over there and checks that both sides moved,
closes it); `WKDDAP_MEMORY_COMPANION=headless` does the same without a window.

## Limits

- What is sent to the adapter stays text, so any 64-bit address is used
  exactly. Addresses *shown* are Lua numbers, exact up to 2^53 (user space on
  the common 64-bit ABIs); above that (kernel-half addresses, ARM64 tagged
  pointers such as Android's `0xb400…`) the header shows `@ ?` and the rows
  show offsets relative to the target instead.
- One view at a time; `:Dap memory` again moves it (same session) or replaces
  it (new session).
