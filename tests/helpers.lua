local Helpers = {}

local expect = MiniTest.expect

---@return table
function Helpers.new_child()
  local child = MiniTest.new_child_neovim()

  --- Runs the plugin's setup in the child. `opts` is merged over test defaults
  --- (no downloads, no delays, highlighting off). Pattern lists mix array and
  --- map entries, which msgpack cannot carry, so pass those as a Lua
  --- expression string instead of a table.
  ---@param opts table|string|nil
  ---@param expect_disabled boolean|nil
  function child.configure(opts, expect_disabled)
    child.lua("h.setup(...)", { opts or {}, expect_disabled or false })
  end

  --- Same, in a freshly started child.
  ---@param opts table|nil
  ---@param expect_disabled boolean|nil
  function child.setup(opts, expect_disabled)
    child.restart({ "-u", "tests/minimal_init.lua" })
    child.lua('_G.h = require("child_helpers")')
    child.configure(opts, expect_disabled)
  end

  return child
end

--- Buffer highlighted by direct `highlight_lines` calls, with no autocmds,
--- timers or view clamping in the way.
---@param child table
---@param lines string[]
---@param ft string|nil
---@return integer
function Helpers.detached(child, lines, ft)
  return child.lua_get("h.detached_buf(...)", { lines, ft })
end

--- Buffer wired into the real pipeline: shown in the current window and
--- attached, so edits and scrolling drive the highlighting.
---@param child table
---@param lines string[]
---@param ft string|nil
---@return integer
function Helpers.live(child, lines, ft)
  return child.lua_get("h.live_buf(...)", { lines, ft })
end

---@param child table
---@param buf integer
function Helpers.rehl(child, buf)
  child.lua("h.rehl(...)", { buf })
end

---@param child table
---@param buf integer
---@param client string|nil
---@return integer[]
function Helpers.ids(child, buf, client)
  return child.lua_get("h.mark_ids(...)", { buf, client })
end

---@param child table
---@param buf integer
---@param expected string[]
---@param client string|nil
function Helpers.expect_marks(child, buf, expected, client)
  expect.equality(child.lua_get("h.marks(...)", { buf, client }), expected)
end

--- Same, but polls while the plugin's timers and scheduled callbacks run.
---@param child table
---@param buf integer
---@param expected string[]
---@param client string|nil
function Helpers.expect_marks_eventually(child, buf, expected, client)
  expect.equality(child.lua_get("h.wait_marks(...)", { buf, expected, client }), expected)
end

---@param child table
---@param buf integer
function Helpers.expect_cache_consistent(child, buf)
  expect.equality(child.lua_get("h.cache_problems(...)", { buf }), {})
end

return Helpers
