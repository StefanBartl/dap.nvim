---@module 'dap_nvim.adapters.lua'
---@brief Lua debugging via one-small-step-for-vimkind (OSV)

local notify = require("lib.nvim.notify").create("[dap.nvim.adapters.lua]")

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
