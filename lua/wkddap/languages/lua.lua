---@module 'wkddap.languages.lua'
--- Lua: adapter + launch configurations for debugging via
--- one-small-step-for-vimkind (OSV)

local notify = require("lib.nvim.notify").create("[dap.nvim.languages.lua]")

local M = {}

--- Setup Lua debugging adapter
---@return boolean success
function M.setup()
  local ok_osv = pcall(require, "osv")
  if not ok_osv then
    return false
  end

  local ok_dap, dap = pcall(require, "dap")
  if not ok_dap then
    return false
  end

  dap.adapters.nlua = function(callback, config)
    callback({
      type = "server",
      host = config.host or "127.0.0.1",
      port = config.port or 8086,
    })
  end

  return true
end

---@return boolean success
function M.load()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  dap.configurations.lua = {
    {
      type = "nlua",
      request = "attach",
      name = "Attach to running Neovim instance",
      -- nvim-dap resolves config functions inside coroutine.wrap(), so an
      -- async prompt works via the same yield/resume idiom nvim-dap's own
      -- async pickers use: yield, let kit.input's on_submit resume the
      -- suspended coroutine with the typed value.
      host = function()
        local co = coroutine.running()
        require("lib.nvim.ui.kit").input({
          title = "Host [127.0.0.1]: ",
          default = "127.0.0.1",
          on_submit = function(input)
            coroutine.resume(co, input)
          end,
          on_cancel = function()
            coroutine.resume(co, "127.0.0.1")
          end,
        })
        return coroutine.yield()
      end,
      port = function()
        local co = coroutine.running()
        require("lib.nvim.ui.kit").input({
          title = "Port [8086]: ",
          default = "8086",
          on_submit = function(input)
            coroutine.resume(co, tonumber(input) or 8086)
          end,
          on_cancel = function()
            coroutine.resume(co, 8086)
          end,
        })
        return coroutine.yield()
      end,
    },
    {
      type = "nlua",
      request = "attach",
      name = "Attach (default: localhost:8086)",
      host = "127.0.0.1",
      port = 8086,
    },
  }

  return true
end

--- Start debug server for current Neovim instance
---@param port? integer Port number (default: 8086)
---@return boolean success
function M.launch_server(port)
  local ok, osv = pcall(require, "osv")
  if not ok then
    notify.error("one-small-step-for-vimkind not available")
    return false
  end

  port = port or 8086
  osv.launch({ port = port })
  notify.info(string.format("Debug server started on port %d", port))
  return true
end

return M
