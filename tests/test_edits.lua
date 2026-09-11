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

T["shifts marks when text before them is deleted"] = function()
  local buf = H.detached(child, { "xxxx #ff0000 bg-red-500" })
  H.rehl(child, buf)
  expect.equality(H.ids(child, buf), { 1, 2 })

  child.api.nvim_buf_set_text(buf, 0, 0, 0, 5, { "" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000", "0:8-18:OCP_fb2c36" })
  expect.equality(H.ids(child, buf), { 1, 2 })

  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000", "0:8-18:OCP_fb2c36" })
  expect.equality(H.ids(child, buf), { 1, 2 })
  H.expect_cache_consistent(child, buf)
end

T["shifts a mark when text is inserted before it"] = function()
  local buf = H.detached(child, { "#ff0000 text" })
  H.rehl(child, buf)
  child.api.nvim_buf_set_text(buf, 0, 0, 0, 0, { "xx" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:2-9:OCP_ff0000" })
  expect.equality(H.ids(child, buf), { 1 })
  H.expect_cache_consistent(child, buf)
end

T["removes a mark split by a new line"] = function()
  local buf = H.detached(child, { "#ffaa00 text" })
  H.rehl(child, buf)
  child.api.nvim_buf_set_text(buf, 0, 3, 0, 3, { "", "" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, {})
  H.expect_cache_consistent(child, buf)
end

T["respects an LSP mark shifted by an edit before it"] = function()
  local buf = H.detached(child, { "xxxx #ff0000 #00ff00" })
  child.lua("h.add_lsp_mark(...)", { buf, 0, 13, 20 })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:5-12:OCP_ff0000" })

  child.api.nvim_buf_set_text(buf, 0, 0, 0, 5, { "" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000" })
  H.expect_cache_consistent(child, buf)
end

T["highlights colors uncovered by a line deletion"] = function()
  child.o.lines = 10
  local lines = {}
  for i = 1, 20 do
    lines[i] = "line " .. i
  end
  lines[15] = "#ff0000"
  local buf = H.live(child, lines)

  child.api.nvim_buf_set_lines(buf, 0, 10, false, {})
  H.expect_marks_eventually(child, buf, { "4:0-7:OCP_ff0000" })
  H.expect_cache_consistent(child, buf)
end

return T
