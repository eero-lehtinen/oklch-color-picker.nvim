local H = require("helpers")
local expect = MiniTest.expect

local child = H.new_child()

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      child.setup()
    end,
    post_once = child.stop,
  },
})

T["creates marks"] = function()
  local buf = H.detached(child, { "#ff0000 and bg-red-500" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000", "0:12-22:OCP_fb2c36" })
  H.expect_cache_consistent(child, buf)
end

T["reuses marks on an unchanged line"] = function()
  local buf = H.detached(child, { "#ff0000 and bg-red-500" })
  H.rehl(child, buf)
  local before = H.ids(child, buf)
  H.rehl(child, buf)
  expect.equality(H.ids(child, buf), before)
  H.expect_cache_consistent(child, buf)
end

T["replaces a mark whose text changed in place"] = function()
  local buf = H.detached(child, { "#ff0000 text" })
  H.rehl(child, buf)
  child.api.nvim_buf_set_text(buf, 0, 1, 0, 7, { "00ff00" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_00ff00" })
  H.expect_cache_consistent(child, buf)
end

T["deletes marks whose color is gone"] = function()
  local buf = H.detached(child, { "#ff0000 text" })
  H.rehl(child, buf)
  child.api.nvim_buf_set_text(buf, 0, 1, 0, 3, { "zz" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, {})
  expect.equality(child.lua_get("next(h.data[...].mark_caches[h.ns].texts) == nil", { buf }), true)
end

T["keeps mark caches separate per buffer"] = function()
  local a = H.detached(child, { "#ff0000 text" })
  local b = H.detached(child, { "#00ff00 text" })
  H.rehl(child, a)
  H.rehl(child, b)
  -- Both buffers hand out mark id 1; b's entry must not shadow a's.
  expect.equality(H.ids(child, a), H.ids(child, b))
  H.rehl(child, a)
  H.expect_marks(child, a, { "0:0-7:OCP_ff0000" })
  expect.equality(H.ids(child, a), { 1 })
  H.expect_cache_consistent(child, a)
  H.expect_cache_consistent(child, b)
end

T["keeps mark caches separate per namespace"] = function()
  local buf = H.detached(child, { "#ff0000 #00ff00" })
  H.rehl(child, buf)
  expect.equality(H.ids(child, buf), { 1, 2 })
  -- The LSP namespace also starts at id 1, so this collides with the first
  -- regex mark unless the caches are kept apart.
  child.lua("h.add_lsp_mark(...)", { buf, 0, 8, 15 })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000" })
  expect.equality(H.ids(child, buf), { 1 })
  H.expect_cache_consistent(child, buf)
end

T["adjacent colors"] = MiniTest.new_set({
  parametrize = {
    { "bg-red-500#fff", { "0:0-10:OCP_fb2c36", "0:10-14:OCP_ffffff" } },
    { "#fff bg-red-500", { "0:0-4:OCP_ffffff", "0:5-15:OCP_fb2c36" } },
  },
})

T["adjacent colors"]["both get a mark"] = function(line, expected)
  local buf = H.detached(child, { line })
  H.rehl(child, buf)
  H.expect_marks(child, buf, expected)
  H.expect_cache_consistent(child, buf)
end

T["a color adjacent to an LSP mark still gets a mark"] = function()
  local buf = H.detached(child, { "#ff0000#00ff00" })
  child.lua("h.add_lsp_mark(...)", { buf, 0, 7, 14 })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000" })
  H.expect_cache_consistent(child, buf)
end

T["skips a color inside an LSP mark"] = function()
  local buf = H.detached(child, { "text #ff0000 text" })
  child.lua("h.add_lsp_mark(...)", { buf, 0, 5, 12 })
  H.rehl(child, buf)
  H.expect_marks(child, buf, {})
  H.expect_cache_consistent(child, buf)
end

T["truncates lines at 1000 bytes"] = function()
  local buf = H.live(child, {
    string.rep("x", 990) .. " #ff0000 " .. string.rep("x", 10) .. " #00ff00",
  })
  H.expect_marks_eventually(child, buf, { "0:991-998:OCP_ff0000" })
  H.expect_cache_consistent(child, buf)
end

T["clear_buf_hl empties marks and caches"] = function()
  local buf = H.detached(child, { "#ff0000 text" })
  H.rehl(child, buf)
  child.lua("h.register(...)", { buf })
  child.lua("require('oklch-color-picker.highlight').clear_buf_hl(...)", { buf })

  H.expect_marks(child, buf, {})
  expect.equality(child.lua_get("next(h.data[...].mark_caches) == nil", { buf }), true)

  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000" })
  H.expect_cache_consistent(child, buf)
end

T["handles the stress fixture"] = function()
  local buf = child.lua_get("h.detached_buf(vim.fn.readfile('stress_test.txt'))")
  H.rehl(child, buf)
  expect.equality(child.lua_get("h.mark_count(...)", { buf }), 975)
  local before = H.ids(child, buf)
  H.rehl(child, buf)
  expect.equality(H.ids(child, buf), before)
  H.expect_cache_consistent(child, buf)
end

return T
