--- Test helper for the FileSync busted test suite.
--- Sets up package.path and provides minimal stubs so plugin modules
--- can be loaded without a running KOReader environment.

-- Ensure requires resolve from the project root
local project_root = debug.getinfo(1, "S").source:match("@(.+)/spec/helper%.lua$") or "."
package.path = project_root .. "/?.lua;"
              .. project_root .. "/?/init.lua;"
              .. package.path

-- Stub out KOReader's logger module so any `require("logger")` succeeds.
-- Every method is a silent no-op.
local noop = function() end
package.loaded["logger"] = {
    info  = noop,
    warn  = noop,
    err   = noop,
    dbg   = noop,
}
