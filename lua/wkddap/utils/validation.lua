---@module 'wkddap.utils.validation'
--- Process picker for attach-mode debugging, used by the JS/TS "Attach" config.

local M = {}

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
      require("lib.nvim.ui.kit").select({
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
    --
    -- NOTE: `ps` is Unix-only. On Windows this listing has never worked; the
    -- Windows equivalent would be `tasklist` / a WMI query. Left as-is here
    -- because that is a separate feature gap, not an async question.
    local argv = { "ps", "-eo", "pid,comm" }

    if not vim.system then
      open_picker(vim.fn.systemlist(argv))
      return
    end

    vim.system(argv, { text = true }, function(res)
      local items = {}
      if res.code == 0 and res.stdout and res.stdout ~= "" then
        items = vim.split(res.stdout:gsub("\r?\n$", ""), "\r?\n")
      end
      -- vim.system callbacks run off the main loop; the picker touches
      -- Neovim state and must be scheduled.
      vim.schedule(function()
        open_picker(items)
      end)
    end)
  end)
end

return M
