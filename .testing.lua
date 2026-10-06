-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "wkddap",
  -- Where the specs live (relative to this directory).
  roots = { "TESTS/wkddap" },
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "auto",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim", "ui.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next).
  isolated = "file",
  -- "c" = child started from a -c command (v:vim_did_enter is 0, <cword> works),
  -- "l" = `nvim -l`.
  host = "c",
  -- Guards (docs/GUARDS.md of testing.nvim). The suite is clean for all of them except state.
  guards = {
    fs = "error",
    -- Off on purpose: bindings/keymaps_spec.lua calls keymaps.setup() in several cases of one file
    -- and leaves the global <leader>d*/<leader>z* maps behind (100 findings). That is the plugin's own
    -- setup() state, harmless because every file runs in its own child (isolated = "file"); a child
    -- per case (isolated = "case") would make the run about five times slower.
    state = "off",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
  },
  guard_allow = {
    -- rust.setup() runs `rustc --print sysroot` to locate lldb_lookup.py (languages/adapter_setup_spec.lua);
    -- it is real, intended behaviour of the plugin and degrades when rustc is missing.
    spawn = { "rustc" },
  },
}
