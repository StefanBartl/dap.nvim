---@module 'wkddap.core.breakpoints'
--- Prompting for conditional breakpoints and log points.
---
--- The prompt used to open empty every time, from three separate call sites
--- (keymaps, `:Dap conditional-breakpoint`/`log-point`, and the nvzone/menu
--- entries) that each had their own copy of it. Retyping a condition to fix a
--- typo in it, or to put the same one on the next line, meant typing the whole
--- thing again.
---
--- It now opens with something in it, in this order:
---
---   1. **The value already on a breakpoint at this line.** This is the edit
---      case, and it is the one that matters most: `<leader>dB` on a line that
---      already has a conditional breakpoint now shows that condition instead
---      of pretending there is none.
---   2. **The last value submitted this session.** The reuse case -- the same
---      condition on a second line is usually the point of asking twice.
---   3. Empty.
---
--- Submitting an empty line is kept meaningful rather than treated as a
--- cancel: nvim-dap reads an empty condition as "no condition", so clearing
--- the prompt and pressing `<CR>` turns a conditional breakpoint back into a
--- plain one. `<Esc>` still cancels outright and changes nothing.

local M = {}

---Last non-empty values submitted this session, for the reuse case. Session
---state on purpose: a condition is about the run you are doing now, and
---persisting it across restarts would resurrect a stale one at the worst
---moment.
---@type table<string, string>
local last = {}

---@internal
---@return integer bufnr, integer lnum
local function here()
  return vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1]
end

---The breakpoint nvim-dap currently has at `bufnr:lnum`, if any.
---@internal
---@param bufnr integer
---@param lnum integer
---@return table|nil
local function breakpoint_at(bufnr, lnum)
  local ok, bps = pcall(function()
    return require("dap.breakpoints").get(bufnr)
  end)
  if not ok or type(bps) ~= "table" then
    return nil
  end

  for _, bp in ipairs(bps[bufnr] or {}) do
    if bp.line == lnum then
      return bp
    end
  end
  return nil
end

---@internal
---@param field "condition"|"logMessage"
---@return string
local function prefill(field)
  local bufnr, lnum = here()
  local bp = breakpoint_at(bufnr, lnum)
  local existing = bp and bp[field]
  if type(existing) == "string" and existing ~= "" then
    return existing
  end
  return last[field] or ""
end

---@internal
---@param field "condition"|"logMessage"
---@param title string
---@param apply fun(value: string)
local function ask(field, title, apply)
  require("lib.nvim.ui.kit").input({
    title = title,
    default = prefill(field),
    on_submit = function(value)
      value = value or ""
      if value ~= "" then
        last[field] = value
      end
      apply(value)
    end,
  })
end

---Prompt for a breakpoint condition and set it on the current line.
---
--- Pre-filled with this line's existing condition, else the last one used.
---@return nil
function M.prompt_condition()
  ask("condition", "Breakpoint condition: ", function(condition)
    require("dap").set_breakpoint(condition)
  end)
end

---Prompt for a log-point message and set it on the current line.
---
--- Pre-filled with this line's existing log message, else the last one used.
---@return nil
function M.prompt_log_point()
  ask("logMessage", "Log message: ", function(message)
    require("dap").set_breakpoint(nil, nil, message)
  end)
end

---Forget the remembered values.
---
--- Nothing calls this in normal operation; it exists so a test (or a user who
--- wants a genuinely blank prompt back) can reset the session state without
--- restarting Neovim.
---@return nil
function M.forget()
  last = {}
end

return M
