local H = require("helpers")
local expect = MiniTest.expect

local child = H.new_child()

-- Every case here mutates global plugin state (enabled flag, autocmds,
-- colorscheme, window size), so each gets a fresh child.
local T = MiniTest.new_set({
  hooks = {
    post_once = child.stop,
  },
})

local hl = "require('oklch-color-picker.highlight')"

T["disable clears everything and enable brings it back"] = function()
  child.setup({ highlight = { enabled = true } })
  local buf = H.live(child, { "#ff0000" })
  H.expect_marks_eventually(child, buf, { "0:0-7:OCP_ff0000" })

  child.lua("_G.timer = " .. hl .. ".bufs[...].pending_timer", { buf })
  child.lua(hl .. ".disable()")

  H.expect_marks(child, buf, {})
  expect.equality(child.lua_get("next(" .. hl .. ".bufs) == nil"), true)
  expect.equality(child.lua_get("_G.timer:is_closing()"), true)
  expect.equality(child.lua_get(hl .. ".is_enabled()"), false)

  expect.equality(child.lua_get(hl .. ".toggle()"), true)
  H.expect_marks_eventually(child, buf, { "0:0-7:OCP_ff0000" })
end

T["skips ignored filetypes"] = function()
  child.setup({ highlight = { enabled = true, ignore_ft = { "markdown" } } })
  local ignored = H.live(child, { "#ff0000" }, "markdown")
  local normal = H.live(child, { "#ff0000" }, "lua")
  H.expect_marks_eventually(child, normal, { "0:0-7:OCP_ff0000" })
  H.expect_marks(child, ignored, {})
end

T["skips terminal buffers"] = function()
  child.setup({ highlight = { enabled = true } })
  local buf = H.live(child, { "#ff0000" })
  H.expect_marks_eventually(child, buf, { "0:0-7:OCP_ff0000" })

  local term = child.lua_get("h.term_buf(...)", { "#ff0000" })
  expect.equality(child.bo.buftype, "terminal")
  child.lua(hl .. ".update_lines(..., 0, 1e9, false)", { term })
  H.expect_marks(child, term, {})
end

T["regenerates highlight groups on ColorScheme"] = function()
  child.setup({ highlight = { enabled = true, style = "foreground" } })
  child.api.nvim_set_hl(0, "Normal", { bg = 0x000000 })
  child.lua(hl .. ".update_emphasis_values()")

  local buf = H.live(child, { "#050505" })
  H.expect_marks_eventually(child, buf, { "0:0-7:OCP_050505" })
  -- Near-black on a black background triggers the emphasis tint.
  expect.equality(child.lua_get("vim.api.nvim_get_hl(0, { name = 'OCP_050505' }).bg"), 0x323232)

  child.api.nvim_set_hl(0, "Normal", { bg = 0xffffff })
  child.cmd("doautocmd ColorScheme")
  H.expect_marks_eventually(child, buf, { "0:0-7:OCP_050505" })
  expect.equality(child.lua_get("vim.api.nvim_get_hl(0, { name = 'OCP_050505' }).bg or false"), false)
end

T["view"] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.setup({ highlight = { enabled = true } })
      child.o.lines = 12
    end,
  },
})

---@return integer[]
local function lines_of_colors()
  local lines = {}
  for i = 1, 100 do
    lines[i] = "#ff0000"
  end
  return lines
end

T["view"]["marks the visible lines and one more"] = function()
  local buf = H.live(child, lines_of_colors())
  local bottom = child.lua_get("vim.fn.line('w$')")
  expect.equality(bottom < 100, true)
  expect.equality(child.lua_get("h.wait_marks_count(...)", { buf, bottom + 1 }), bottom + 1)
end

T["view"]["scrolling down marks new lines and keeps the old ones"] = function()
  local buf = H.live(child, lines_of_colors())
  local bottom = child.lua_get("vim.fn.line('w$')")
  expect.equality(child.lua_get("h.wait_marks_count(...)", { buf, bottom + 1 }), bottom + 1)

  child.type_keys("<C-e>")
  expect.equality(child.lua_get("h.wait_marks_count(...)", { buf, bottom + 2 }), bottom + 2)
  expect.equality(H.ids(child, buf)[1], 1)
end

T["view"]["a jump to the end marks the new view"] = function()
  local buf = H.live(child, lines_of_colors())
  local bottom = child.lua_get("vim.fn.line('w$')")
  expect.equality(child.lua_get("h.wait_marks_count(...)", { buf, bottom + 1 }), bottom + 1)

  child.type_keys("G")
  expect.equality(child.lua_get("h.wait_last_mark(...)", { buf, "99:0-7:OCP_ff0000" }), "99:0-7:OCP_ff0000")
end

return T
