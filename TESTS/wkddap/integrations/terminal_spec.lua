--- Covers wkddap.integrations.terminal: the runInTerminal handler (the call handed to terminal.nvim,
--- the answer to the adapter) and which adapters get it. terminal.nvim and nvim-dap are not on this
--- suite's runtimepath, so both are doubles.

local terminal_integration = require("wkddap.integrations.terminal")

local OPTS = { enable = true, layout = "split", name = "dap" }

---@return table session, table[] responses
local function fake_session(name)
  local responses = {}
  return {
    config = name and { name = name } or nil,
    response = function(_, request, response)
      responses[#responses + 1] = { request = request, response = response }
    end,
  },
    responses
end

describe("wkddap.integrations.terminal handler", function()
  it("starts the program as a direct, named terminal job and answers with its pid", function()
    local got
    local fake = {
      run = function(cmd, opts)
        got = { cmd = cmd, opts = opts }
        return true, nil, { job = -1 }
      end,
    }
    local session, responses = fake_session("Launch file")
    local real_jobpid = vim.fn.jobpid
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.fn.jobpid = function()
      return 4242
    end
    terminal_integration.handler(OPTS, fake)(session, {
      arguments = { args = { "node", "app.js" }, cwd = "/work", env = { A = "1", B = vim.NIL } },
    })
    vim.fn.jobpid = real_jobpid

    assert.are.same({ "node", "app.js" }, got.cmd)
    assert.are.equal("dap:Launch file", got.opts.name)
    assert.is_true(got.opts.direct)
    assert.are.equal("split", got.opts.layout)
    assert.are.equal("/work", got.opts.cwd)
    assert.are.equal("never", got.opts.close)
    assert.is_false(got.opts.focus)
    assert.are.same({ A = "1" }, got.opts.env, "a null (unset) variable is dropped, not sent")
    assert.is_true(responses[1].response.success)
    assert.are.equal(4242, responses[1].response.body.processId)
  end)

  it("answers without a pid for a pane that has no job", function()
    local fake = {
      run = function()
        return true, nil, { pane = "%3" }
      end,
    }
    local session, responses = fake_session("x")
    terminal_integration.handler(OPTS, fake)(session, { arguments = { args = { "a" } } })
    assert.is_true(responses[1].response.success)
    assert.is_nil(responses[1].response.body.processId)
  end)

  it("answers with an error when the terminal cannot start", function()
    local fake = {
      run = function()
        return false, "no backend"
      end,
    }
    local session, responses = fake_session("x")
    terminal_integration.handler(OPTS, fake)(session, { arguments = { args = { "a" } } })
    assert.is_false(responses[1].response.success)
    assert.is_truthy(responses[1].response.message:find("no backend", 1, true))
  end)

  it("answers with an error for a request without a command", function()
    local fake = {
      run = function()
        error("must not be called")
      end,
    }
    local session, responses = fake_session("x")
    terminal_integration.handler(OPTS, fake)(session, { arguments = { args = {} } })
    assert.is_false(responses[1].response.success)
  end)

  it("labels an unnamed configuration with the program", function()
    local got
    local fake = {
      run = function(_, opts)
        got = opts
        return true, nil, {}
      end,
    }
    local session = fake_session(nil)
    terminal_integration.handler(OPTS, fake)(
      session,
      { arguments = { args = { "python", "m.py" } } }
    )
    assert.are.equal("dap:python", got.name)
  end)
end)

describe("wkddap.integrations.terminal install", function()
  it("does nothing when disabled", function()
    local dap = { adapters = { a = {} } }
    assert.are.equal(0, terminal_integration.install({ enable = false }, dap))
    assert.is_nil(dap.adapters.a.reverse_request_handlers)
  end)

  it("adds the handler to table adapters and keeps one the user set", function()
    local mine = function() end
    local dap = {
      adapters = {
        plain = { type = "executable" },
        custom = { reverse_request_handlers = { runInTerminal = mine } },
      },
    }
    assert.are.equal(1, terminal_integration.install(OPTS, dap))
    assert.are.equal("function", type(dap.adapters.plain.reverse_request_handlers.runInTerminal))
    assert.are.equal("executable", dap.adapters.plain.type)
    assert.are.equal(mine, dap.adapters.custom.reverse_request_handlers.runInTerminal)
  end)

  it("wraps a function adapter: the table it resolves to gets the handler", function()
    local seen_config
    local dap = {
      adapters = {
        lazy = function(callback, config)
          seen_config = config
          callback({ type = "server", port = 1 })
        end,
      },
    }
    assert.are.equal(1, terminal_integration.install(OPTS, dap))
    local resolved
    dap.adapters.lazy(function(adapter)
      resolved = adapter
    end, { name = "cfg" })
    assert.are.same({ name = "cfg" }, seen_config)
    assert.are.equal("server", resolved.type)
    assert.are.equal("function", type(resolved.reverse_request_handlers.runInTerminal))
  end)
end)
