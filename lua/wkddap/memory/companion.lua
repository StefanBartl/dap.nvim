---@module 'wkddap.memory.companion'
--- The memory view in a companion window: a second Neovim in its own terminal
--- window (`lib.nvim.companion`), read-only, fed with the very same lines and
--- highlights `format.render` produces for the float. The second
--- implementation of the view's window layer (`open/show/close/is_valid/
--- focus_byte/cursor_byte`, see `wkddap.memory.view`), so the controller
--- (`wkddap.memory`) does not care which one it draws on.
---
--- Logic and state stay in this instance: a key in the companion arrives as a
--- named action (`page`, `toggle_mode`, `refresh`, `jump`) that calls the
--- handler the controller passed in; the companion itself never talks DAP.
--- `a` asks for the address in the companion (`vim.ui.input` there) and sends
--- the text along. Editing (`writeMemory`) is deliberately not offered here:
--- the companion is a display; the float keeps the edit keys.
---
--- The companion is `nvim -u NONE`, so the plugin's own highlight group
--- (`WkddapMemoryTarget`) does not exist there: it is sent as its default
--- link (`Search`). The cursor lives in the other process: `focus_byte` is a
--- no-op and `cursor_byte` answers nil (the companion keeps its own cursor
--- line across updates).

local format = require("wkddap.memory.format")

local M = {}

---Key legend shown under the data rows: the companion's keys only.
M.LEGEND = "a address  n/p page  b hex/bits  r refresh  q close"

---@class Dap.MemoryCompanionView
---@field handle Lib.Companion.Handle
---@field render Dap.MemoryRender|nil the last render pushed
---@field title string the last title pushed

---@class Dap.MemoryCompanionOpts
---@field terminal? string[]|false argv template for the terminal window, or false for a
---  headless companion (scripts); nil = the platform's default terminal

---@internal
---@param render Dap.MemoryRender
---@return string[]
local function with_legend(render)
  local lines = vim.list_extend({}, render.lines)
  lines[#lines + 1] = ""
  lines[#lines + 1] = M.LEGEND
  return lines
end

---The render's highlights as the companion takes them: `WkddapMemoryTarget`
---(unknown over there) becomes `Search`, plus the legend in `Comment`.
---@internal
---@param render Dap.MemoryRender
---@param line_count integer
---@return Lib.Companion.Highlight[]
local function highlights_of(render, line_count)
  local out = {}
  for _, hl in ipairs(render.highlights) do
    out[#out + 1] = {
      line = hl.line,
      col_start = hl.col_start,
      col_end = hl.col_end,
      group = hl.group == format.TARGET_GROUP and "Search" or hl.group,
    }
  end
  out[#out + 1] = { line = line_count - 1, col_start = 0, col_end = #M.LEGEND, group = "Comment" }
  return out
end

---@param view Dap.MemoryCompanionView|nil
---@return boolean
function M.is_valid(view)
  return view ~= nil and view.handle ~= nil and view.handle:is_open()
end

---The companion's cursor is in another process: unknown here.
---@param _view Dap.MemoryCompanionView
---@return integer|nil index
---@return integer|nil bit
function M.cursor_byte(_view)
  return nil, nil
end

---No cursor to move from here; the companion keeps its own.
---@param _view Dap.MemoryCompanionView
---@param _index integer
---@param _bit? integer
function M.focus_byte(_view, _index, _bit) end

---Push `render` (and `title`, when it changed) to the companion.
---@param view Dap.MemoryCompanionView
---@param render Dap.MemoryRender
---@param title string
function M.show(view, render, title)
  if not M.is_valid(view) then
    return
  end
  view.render = render
  if title ~= view.title then
    view.title = title
    view.handle:set_title(title)
  end
  local lines = with_legend(render)
  view.handle:update(lines, highlights_of(render, #lines))
end

---Open the companion window with `render` and bind its keys to `handlers`.
---nil and the reason when the companion could not be started (no terminal,
---no RPC server, ...).
---@param render Dap.MemoryRender
---@param title string
---@param handlers Dap.MemoryHandlers
---@param opts? Dap.MemoryCompanionOpts
---@return Dap.MemoryCompanionView|nil
---@return string|nil err
function M.open(render, title, handlers, opts)
  opts = opts or {}
  local lines = with_legend(render)
  local handle, err = require("lib.nvim.companion").open({
    title = title,
    lines = lines,
    highlights = highlights_of(render, #lines),
    filetype = "wkddap-memory",
    actions = {
      page = function(delta)
        handlers.page(tonumber(delta) or 1)
      end,
      toggle_mode = function()
        handlers.toggle_mode()
      end,
      refresh = function()
        handlers.refresh()
      end,
      -- The text the companion's prompt got; an empty one is ignored instead
      -- of opening a prompt in this instance (the user is at the other one).
      jump = function(target)
        target = type(target) == "string" and vim.trim(target) or ""
        if target ~= "" then
          handlers.jump(target)
        end
      end,
    },
    keys = {
      a = { "jump", prompt = "Memory address or expression: " },
      n = { "page", 1 },
      p = { "page", -1 },
      b = "toggle_mode",
      r = "refresh",
    },
    on_close = handlers.closed,
    terminal = opts.terminal,
  })
  if not handle then
    return nil, err
  end
  ---@type Dap.MemoryCompanionView
  return { handle = handle, render = render, title = title }, nil
end

---@param view Dap.MemoryCompanionView|nil
function M.close(view)
  if M.is_valid(view) then
    ---@cast view Dap.MemoryCompanionView
    view.handle:close()
  end
end

return M
