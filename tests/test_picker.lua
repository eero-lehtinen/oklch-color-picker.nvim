local H = require("helpers")
local expect = MiniTest.expect

local child = H.new_child()

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      child.setup()
      child.lua("h.stub_system()")
    end,
    post_once = child.stop,
  },
})

local picker = "require('oklch-color-picker.picker')"

---@param line string
---@param col integer 1-based cursor column
---@return integer
local function buf_with_cursor(line, col)
  local buf = H.live(child, { line })
  child.api.nvim_win_set_cursor(0, { 1, col - 1 })
  return buf
end

T["color_under_cursor"] = MiniTest.new_set({
  parametrize = {
    { "text #ff0000 text", 8, { pos = { 6, 13 }, color = "#ff0000" } },
    { "text #ff0000 text", 13, vim.NIL },
    { "bg-red-500", 1, { pos = { 4, 11 }, color = "#fb2c36" } },
    { "#ff0000 #00ff00", 10, { pos = { 9, 16 }, color = "#00ff00" } },
  },
})

T["color_under_cursor"]["finds the color under the cursor"] = function(line, col, expected)
  buf_with_cursor(line, col)
  expect.equality(child.lua_get(picker .. ".color_under_cursor()"), expected)
end

T["color_under_cursor passes on a custom pattern's format"] = function()
  child.configure([[{
    patterns = {
      numbers_in_brackets = false,
      glsl_vec = { format = "raw_rgb_float", "vec3%(()[%d.,%s]+()%)" },
    },
  }]])
  buf_with_cursor("vec3(1,0.5,0)", 3)
  expect.equality(
    child.lua_get(picker .. ".color_under_cursor()"),
    { pos = { 6, 13 }, color = "1,0.5,0", color_format = "raw_rgb_float" }
  )
  child.configure()
end

T["color_under_cursor falls back to LSP colors"] = function()
  local buf = buf_with_cursor("color: blue", 9)
  child.lua(
    "require('oklch-color-picker.highlight').bufs[...].lsp_colors = { cssls = { { packed_color = 0x0000ff, range = { start = { line = 0, character = 7 }, ['end'] = { line = 0, character = 11 } } } } }",
    { buf }
  )
  expect.equality(child.lua_get(picker .. ".color_under_cursor()"), { pos = { 8, 12 }, color = "#0000ff" })
end

T["pick_under_cursor launches the app and applies its result"] = function()
  local buf = buf_with_cursor("color: #ff0000", 9)
  expect.equality(child.lua_get(picker .. ".pick_under_cursor('hex')"), true)
  expect.equality(child.lua_get("h.system_calls[#h.system_calls].cmd"), { "fake-picker", "#ff0000", "--format", "hex" })

  child.lua("h.picker_reply(...)", { "#00ff00\n" })
  expect.equality(child.lua_get("h.wait_line(...)", { buf, 0, "color: #00ff00" }), "color: #00ff00")
end

T["pick_under_cursor does not apply to a buffer edited meanwhile"] = function()
  local buf = buf_with_cursor("color: #ff0000", 9)
  expect.equality(child.lua_get(picker .. ".pick_under_cursor()"), true)
  child.api.nvim_buf_set_text(buf, 0, 0, 0, 0, { "x" })

  child.lua("h.picker_reply(...)", { "#00ff00\n" })
  expect.equality(child.lua_get("h.wait_notification(...)", { "buffer has changed" }) ~= vim.NIL, true)
  expect.equality(child.api.nvim_buf_get_lines(buf, 0, 1, false), { "xcolor: #ff0000" })
end

T["pick_under_cursor reports no color"] = function()
  buf_with_cursor("plain text", 3)
  expect.equality(child.lua_get(picker .. ".pick_under_cursor()"), false)
  expect.equality(child.lua_get("h.wait_notification(...)", { "No color under cursor" }) ~= vim.NIL, true)
end

T["open_picker inserts at the cursor"] = function()
  local buf = buf_with_cursor("abcdefg", 5)
  expect.equality(child.lua_get(picker .. ".open_picker({ initial_color = '#123456' })"), true)
  expect.equality(child.lua_get("h.system_calls[#h.system_calls].cmd"), { "fake-picker", "#123456" })

  child.lua("h.picker_reply(...)", { "#00ff00\n" })
  expect.equality(child.lua_get("h.wait_line(...)", { buf, 0, "abcd#00ff00efg" }), "abcd#00ff00efg")
end

return T
