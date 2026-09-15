--- Covers wkddap.bindings.autocmds.setup(): the enable gate, and that the
--- registered autocmds actually toggle 'cursorline' on the User events
--- nvim-dap-ui emits -- fired directly via nvim_exec_autocmds rather than a
--- real dap-ui session.

local autocmds = require("wkddap.bindings.autocmds")

local function augroup_exists(name)
  return pcall(vim.api.nvim_get_autocmds, { group = name })
end

describe("wkddap.bindings.autocmds.setup()", function()
  after_each(function()
    pcall(vim.api.nvim_del_augroup_by_name, "DapNvimAuto")
  end)

  it("does not create the augroup when disabled", function()
    autocmds.setup({ enable = false })
    assert.is_false(augroup_exists("DapNvimAuto"))
  end)

  it("creates the augroup with both User autocmds when enabled", function()
    autocmds.setup({ enable = true })
    assert.is_true(augroup_exists("DapNvimAuto"))

    local cmds = vim.api.nvim_get_autocmds({ group = "DapNvimAuto" })
    assert.are.equal(2, #cmds)
  end)

  it("enables cursorline on DapUIWindowOpen and disables it on DapUIWindowClose", function()
    autocmds.setup({ enable = true })

    vim.wo.cursorline = false
    vim.api.nvim_exec_autocmds("User", { pattern = "DapUIWindowOpen" })
    assert.is_true(vim.wo.cursorline)

    vim.api.nvim_exec_autocmds("User", { pattern = "DapUIWindowClose" })
    assert.is_false(vim.wo.cursorline)
  end)

  it("re-running setup() clears the group instead of stacking duplicate autocmds", function()
    autocmds.setup({ enable = true })
    autocmds.setup({ enable = true })

    local cmds = vim.api.nvim_get_autocmds({ group = "DapNvimAuto" })
    assert.are.equal(2, #cmds)
  end)
end)
