---@module 'wkddap.memory.view'
--- The memory view's window: one `ui.kit.surface` float in this Neovim, its
--- buffer-local keys, the cell highlights, and the cursor/mouse -> byte lookup.
---
--- Why `ui.kit.surface` and not `ui.kit.viewer`: the viewer closes itself as
--- soon as focus leaves it, and every edit/jump opens a `ui.kit.input` prompt
--- -- the view would be gone by the time the answer arrives. A surface is the
--- same themed float (border, title, `q`/`<Esc>`, `winfixbuf`, on_close
--- lifecycle) without that policy. A plain hand-rolled scratch float would
--- re-implement exactly what surface already does.
---
--- The view knows nothing about DAP: every key calls a handler the controller
--- (`wkddap.memory`) passes in, with the byte (and bit) under the cursor.

local format = require("wkddap.memory.format")

local M = {}

local NS = vim.api.nvim_create_namespace("wkddap_memory")

---@class Dap.MemoryHandlers
---@field edit fun(index: integer|nil)
---@field toggle_bit fun(index: integer|nil, bit: integer|nil)
---@field click fun(index: integer|nil, bit: integer|nil)
---@field undo fun()
---@field toggle_mode fun()
---@field jump fun()
---@field page fun(delta: integer)
---@field refresh fun()
---@field closed fun()

---@class Dap.MemoryView
---@field surface Lib.UI.Kit.Surface
---@field render Dap.MemoryRender|nil the last render, for the cursor lookup

---Key legend shown under the data rows. Kept next to the mappings below so
---the two cannot drift apart unnoticed.
M.LEGEND = "e/<CR> edit  <Space> bit  u undo  b hex/bits  a address  n/p page  r refresh  q close"

---@internal
---@param lines string[]
---@return integer width, integer height
local function size(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local height = math.min(#lines, math.max(vim.o.lines - 6, 5))
  return math.min(width, math.max(vim.o.columns - 4, 20)), height
end

---@internal
---@param render Dap.MemoryRender
---@return string[]
local function with_legend(render)
  local lines = vim.list_extend({}, render.lines)
  lines[#lines + 1] = ""
  lines[#lines + 1] = M.LEGEND
  return lines
end

---The byte (and bit) under the cursor of the view.
---@param view Dap.MemoryView
---@return integer|nil index
---@return integer|nil bit
function M.cursor_byte(view)
  if not view.render or not M.is_valid(view) then
    return nil, nil
  end
  local pos = vim.api.nvim_win_get_cursor(view.surface.winid)
  return format.position_to_byte(view.render, pos[1], pos[2])
end

---The byte (and bit) under the mouse, falling back to the cursor when the
---click was not in this view's window.
---@param view Dap.MemoryView
---@return integer|nil index
---@return integer|nil bit
local function mouse_byte(view)
  local mouse = vim.fn.getmousepos()
  if view.render and mouse.winid == view.surface.winid and mouse.line > 0 then
    return format.position_to_byte(view.render, mouse.line, mouse.column - 1)
  end
  return M.cursor_byte(view)
end

---@param view Dap.MemoryView|nil
---@return boolean
function M.is_valid(view)
  return view ~= nil and view.surface ~= nil and view.surface:is_valid()
end

---Replace the content with `render`, resize the float to fit and re-apply the
---highlights. The cursor stays on the byte it was on (clamped to the new
---content); the controller moves it to the target with `focus_byte` after the
---first read of an open or a jump.
---@param view Dap.MemoryView
---@param render Dap.MemoryRender
---@param title string
function M.show(view, render, title)
  if not M.is_valid(view) then
    return
  end
  local winid, bufnr = view.surface.winid, view.surface.bufnr
  local cursor = vim.api.nvim_win_get_cursor(winid)
  -- The byte under the cursor before the redraw: the layout moves when the
  -- mode or the address width changes, the cursor should stay on that byte.
  local index, bit = M.cursor_byte(view)
  local lines = with_legend(render)
  view.render = render
  view.surface:set_lines(lines)
  view.surface:set_title(title)

  local width, height = size(lines)
  pcall(vim.api.nvim_win_set_config, winid, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
  })

  -- Defined on every redraw (as a default link, so a user's own definition
  -- wins): a colorscheme change clears groups nobody re-creates.
  vim.api.nvim_set_hl(0, format.TARGET_GROUP, { link = "Search", default = true })
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  for _, hl in ipairs(render.highlights) do
    pcall(vim.api.nvim_buf_set_extmark, bufnr, NS, hl.line, hl.col_start, {
      end_col = hl.col_end,
      hl_group = hl.group,
      priority = hl.priority,
    })
  end
  pcall(
    vim.api.nvim_buf_set_extmark,
    bufnr,
    NS,
    #lines - 1,
    0,
    { end_col = #M.LEGEND, hl_group = "Comment" }
  )

  if index and render.rows > 0 then
    M.focus_byte(view, index, render.layout.mode == "bits" and bit or nil)
    return
  end
  local lnum = math.min(math.max(cursor[1], render.first_row), #lines)
  pcall(vim.api.nvim_win_set_cursor, winid, { lnum, cursor[2] })
end

---Put the cursor on byte `index` (and bit `bit`, bits mode) of the current
---render.
---@param view Dap.MemoryView
---@param index integer
---@param bit? integer
function M.focus_byte(view, index, bit)
  if not view.render or not M.is_valid(view) or view.render.rows == 0 then
    return
  end
  local lnum, col = format.byte_to_position(view.render, index)
  pcall(vim.api.nvim_win_set_cursor, view.surface.winid, { lnum, col + (bit or 0) })
end

---Open the float and bind its keys. nil when the float could not be created.
---@param render Dap.MemoryRender
---@param title string
---@param handlers Dap.MemoryHandlers
---@return Dap.MemoryView|nil
function M.open(render, title, handlers)
  local lines = with_legend(render)
  local width, height = size(lines)
  local surface = require("ui.kit.surface").open({
    lines = lines,
    title = title,
    width = width,
    height = height,
    relative = "editor",
    enter = true,
    nice_quit = true,
    modifiable = false,
    filetype = "wkddap-memory",
    wo = { cursorline = true, wrap = false },
  })
  if not surface then
    return nil
  end

  ---@type Dap.MemoryView
  local view = { surface = surface, render = nil }
  surface:on_close(handlers.closed)

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, {
      buffer = surface.bufnr,
      nowait = true,
      silent = true,
      desc = "Memory view: " .. desc,
    })
  end
  local function edit()
    handlers.edit((M.cursor_byte(view)))
  end
  map("e", edit, "edit byte")
  map("<CR>", edit, "edit byte")
  map("<Space>", function()
    handlers.toggle_bit(M.cursor_byte(view))
  end, "toggle bit (bits mode)")
  map("<2-LeftMouse>", function()
    handlers.click(mouse_byte(view))
  end, "edit byte / toggle bit")
  map("u", handlers.undo, "undo last write")
  map("b", handlers.toggle_mode, "toggle hex/bits")
  map("a", handlers.jump, "go to address or expression")
  map("n", function()
    handlers.page(1)
  end, "next page")
  map("p", function()
    handlers.page(-1)
  end, "previous page")
  map("<PageDown>", function()
    handlers.page(1)
  end, "next page")
  map("<PageUp>", function()
    handlers.page(-1)
  end, "previous page")
  map("r", handlers.refresh, "refresh")

  M.show(view, render, title)
  M.focus_byte(view, 1)
  return view
end

---@param view Dap.MemoryView|nil
function M.close(view)
  if M.is_valid(view) then
    ---@cast view Dap.MemoryView
    view.surface:close()
  end
end

return M
