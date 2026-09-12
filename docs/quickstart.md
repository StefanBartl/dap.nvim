# Quickstart

Open a file in one of the supported languages, put the cursor on a line, and
start a session:

```vim
:Dap toggle-breakpoint
:Dap continue
```

Or with the default keys — `<leader>db` to break, `<leader>dc` to run. The
full set is the [bindings cheatsheet](BINDINGS.md).

Before anything else, check that the adapter for your language was actually
found:

```vim
:checkhealth wkddap
```

See [WORKFLOW.md](WORKFLOW.md) for how the pieces combine once a session is
actually running.
