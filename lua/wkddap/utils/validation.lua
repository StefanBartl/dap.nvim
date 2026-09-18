---@module 'wkddap.utils.validation'
--- Process picker for attach-mode debugging, used by the JS/TS "Attach" config.

local cross = require("lib.nvim.cross")
local notify = require("wkddap.utils.notify")

local M = {}

---@internal
---The process-listing command for this platform. `ps` does not exist on
---Windows -- spawning it there throws ENOENT -- and `tasklist` is always
---present; its CSV form is the one with a stable shape to parse.
---@return string[] argv
local function listing_argv()
  if cross.is_windows() then
    return { "tasklist", "/FO", "CSV", "/NH" }
  end
  return { "ps", "-eo", "pid,comm" }
end

--- Turn process-listing output into picker items that start with the pid.
--- `ps -eo pid,comm` lines already do; tasklist's CSV rows
--- (`"name","pid",...`) are rewritten to `pid name` so the same pid match in
--- on_select works for both. Blank lines are dropped.
---@param stdout string|nil
---@return string[] items
function M.parse_process_list(stdout)
  local items = {}
  for line in (stdout or ""):gmatch("[^\r\n]+") do
    local name, pid = line:match('^"([^"]*)","(%d+)"')
    if name then
      items[#items + 1] = pid .. " " .. name
    elseif line:match("%S") then
      items[#items + 1] = line
    end
  end
  return items
end

--- Pick a process ID for attach-mode debugging (used by JS/TS "Attach").
---@return thread|nil pid
function M.pick_process()
  local co = coroutine.running()
  if not co then
    return nil
  end

  return coroutine.create(function()
    -- nvim-dap resumes `co` and blocks waiting for it, so a cancelled pick
    -- must still resume (with nil) or the DAP launch hangs forever --
    -- hence on_cancel, which kit.select guarantees fires exactly once for
    -- a dismissal, an empty list, or a float that could not open. The same
    -- applies to the process listing failing: resume with nil, never fall
    -- through without resuming.
    local function open_picker(items)
      require("ui.kit").select({
        items = items,
        title = "Select process:",
        on_select = function(choice)
          coroutine.resume(co, tonumber(choice:match("^%s*(%d+)")))
        end,
        on_cancel = function()
          coroutine.resume(co, nil)
        end,
      })
    end

    -- Process listing used to run through vim.fn.systemlist(), which blocked
    -- the UI thread for the duration of the spawn. vim.system() delivers the
    -- output via callback instead; the picker opens once it arrives.
    local argv = listing_argv()

    if not vim.system then
      open_picker(M.parse_process_list(table.concat(vim.fn.systemlist(argv), "\n")))
      return
    end

    -- vim.system throws (ENOENT) when the command does not exist at all, it
    -- does not report that through res.code -- and a throw here would leave
    -- nvim-dap waiting on `co` forever. Same outcome as a failed listing:
    -- an empty picker, which cancels and resumes with nil.
    local ok, err = pcall(vim.system, argv, { text = true }, function(res)
      local items = {}
      if res.code == 0 then
        items = M.parse_process_list(res.stdout)
      end
      -- vim.system callbacks run off the main loop; the picker touches
      -- Neovim state and must be scheduled.
      vim.schedule(function()
        open_picker(items)
      end)
    end)
    if not ok then
      notify.warn(string.format("process listing (%s) failed: %s", argv[1], tostring(err)))
      -- Scheduled, not inline: `co` is still running at this point (it just
      -- resumed this thread), so it cannot be resumed synchronously.
      vim.schedule(function()
        open_picker({})
      end)
    end
  end)
end

return M
