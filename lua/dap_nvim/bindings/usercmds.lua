---@module 'dap_nvim.bindings.usercmds'
---@brief Registers user commands mirroring the default keymaps 1:1.

local M = {}

function M.setup()
  local function dap()
    return require("dap")
  end

  vim.api.nvim_create_user_command("DapContinue", function()
    dap().continue()
  end, { desc = "[DAP] Continue" })

  vim.api.nvim_create_user_command("DapStepOver", function()
    dap().step_over()
  end, { desc = "[DAP] Step Over" })

  vim.api.nvim_create_user_command("DapStepInto", function()
    dap().step_into()
  end, { desc = "[DAP] Step Into" })

  vim.api.nvim_create_user_command("DapStepOut", function()
    dap().step_out()
  end, { desc = "[DAP] Step Out" })

  vim.api.nvim_create_user_command("DapTerminate", function()
    dap().terminate()
  end, { desc = "[DAP] Terminate" })

  vim.api.nvim_create_user_command("DapRestart", function()
    dap().restart()
  end, { desc = "[DAP] Restart" })

  vim.api.nvim_create_user_command("DapToggleBreakpoint", function()
    dap().toggle_breakpoint()
  end, { desc = "[DAP] Toggle Breakpoint" })

  vim.api.nvim_create_user_command("DapListBreakpoints", function()
    dap().list_breakpoints()
  end, { desc = "[DAP] List Breakpoints" })

  vim.api.nvim_create_user_command("DapToggleUI", function()
    require("dapui").toggle()
  end, { desc = "[DAP] Toggle UI" })

  vim.api.nvim_create_user_command("DapEval", function()
    require("dapui").eval()
  end, { desc = "[DAP] Evaluate Expression" })
end

return M
