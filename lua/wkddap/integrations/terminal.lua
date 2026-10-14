---@module 'wkddap.integrations.terminal'
--- Debug runs in a named terminal.nvim terminal. When the debug adapter asks the editor to start the
--- program ("runInTerminal"), nvim-dap opens a buffer of its own and runs the job in it. With
--- `terminal.enable` the adapters get a `runInTerminal` handler that starts the program as a
--- `direct` job of a terminal.nvim terminal instead (`dap:<configuration name>`): it follows
--- terminal.nvim's window options, shows up in `:Terminal list`, can be hidden and toggled back, and
--- a new run under the same name replaces the earlier terminal.
---
--- terminal.nvim is a soft dependency: the handlers are only installed when `require("terminal")`
--- works, and a handler whose terminal cannot start answers the adapter with an error (the
--- adapter then reports it) instead of falling back, because nvim-dap's own handler is not
--- reachable from outside.

local M = {}

---@class Dap.TerminalOptions
---@field enable boolean Start debuggee programs in a terminal.nvim terminal (default false)
---@field layout string Window layout of that terminal: `split`, `vsplit`, `float` or `tab` (default `split`)
---@field name string Prefix of the terminal name, followed by the configuration name (default `dap`)

---@internal
--- The environment of the request as plain strings (the adapter may send `null` to unset a variable,
--- which a terminal job cannot express).
---@param env any
---@return table<string, string>|nil
local function plain_env(env)
  if type(env) ~= "table" then
    return nil
  end
  local out
  for key, value in pairs(env) do
    if type(key) == "string" and (type(value) == "string" or type(value) == "number") then
      out = out or {}
      out[key] = tostring(value)
    end
  end
  return out
end

--- The `runInTerminal` reverse-request handler.
---@param opts Dap.TerminalOptions
---@param terminal? table Test double for `require("terminal")`
---@return fun(session: table, request: table)
function M.handler(opts, terminal)
  return function(session, request)
    local body = request.arguments or {}
    local term = terminal or select(2, pcall(require, "terminal"))
    if type(term) ~= "table" or type(term.run) ~= "function" then
      session:response(request, { success = false, message = "terminal.nvim is not available" })
      return
    end
    if type(body.args) ~= "table" or #body.args == 0 then
      session:response(request, { success = false, message = "runInTerminal: no command" })
      return
    end
    local label = session.config and session.config.name or body.args[1]
    local ok, err, handle = term.run(body.args, {
      direct = true,
      name = ("%s:%s"):format(opts.name, label),
      layout = opts.layout,
      cwd = (type(body.cwd) == "string" and body.cwd ~= "") and body.cwd or nil,
      env = plain_env(body.env),
      focus = false,
      close = "never",
    })
    if not ok then
      session:response(request, {
        success = false,
        message = "Could not start the terminal: " .. tostring(err),
      })
      return
    end
    local pid = handle and handle.job and vim.fn.jobpid(handle.job) or nil
    session:response(request, { success = true, body = { processId = pid } })
  end
end

---@internal
--- `adapter` (a table) with the handler added; one the user set himself stays.
---@param adapter table
---@param handler function
---@return table
local function with_handler(adapter, handler)
  local handlers = adapter.reverse_request_handlers
  if type(handlers) == "table" and handlers.runInTerminal then
    return adapter
  end
  return vim.tbl_extend("force", adapter, {
    reverse_request_handlers = vim.tbl_extend("force", handlers or {}, { runInTerminal = handler }),
  })
end

--- Add the handler to every adapter nvim-dap knows now (call after the adapters were registered).
--- An adapter given as a function is wrapped: the table it hands to its callback gets the handler.
---@param opts Dap.TerminalOptions
---@param dap? table Test double for `require("dap")`
---@return integer installed # How many adapters were changed
function M.install(opts, dap)
  if not opts or not opts.enable then
    return 0
  end
  if not pcall(require, "terminal") and not dap then
    return 0
  end
  dap = dap or require("dap")
  local handler = M.handler(opts)
  local installed = 0
  for name, adapter in pairs(dap.adapters) do
    if type(adapter) == "table" then
      local changed = with_handler(adapter, handler)
      if changed ~= adapter then
        dap.adapters[name] = changed
        installed = installed + 1
      end
    elseif type(adapter) == "function" then
      dap.adapters[name] = function(callback, config, parent)
        return adapter(function(resolved)
          callback(type(resolved) == "table" and with_handler(resolved, handler) or resolved)
        end, config, parent)
      end
      installed = installed + 1
    end
  end
  return installed
end

return M
