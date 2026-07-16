---@module 'dap_nvim.configurations.lua'
---@brief Launch configurations for Lua debugging

local M = {}

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
      host = function()
        return vim.fn.input("Host [127.0.0.1]: ", "127.0.0.1")
      end,
      port = function()
        return tonumber(vim.fn.input("Port [8086]: ", "8086")) or 8086
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

return M
