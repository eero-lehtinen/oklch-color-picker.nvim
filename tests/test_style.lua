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

---@param mark table
---@param group table
---@return table
local function shape(mark, group)
  return vim.tbl_extend("force", {
    start_col = 0,
    end_col = 7,
    hl_group = false,
    virt_text = false,
    virt_text_group = false,
    virt_text_pos = false,
    right_gravity = true,
    end_right_gravity = false,
  }, mark),
    vim.tbl_extend("force", { fg = false, bg = false, bold = true, italic = true }, group)
end

local inline = { virt_text = "■ ", virt_text_group = "OCP_ff0000", virt_text_pos = "inline", right_gravity = false }
local eol = { virt_text = "■ ", virt_text_group = "OCP_ff0000", virt_text_pos = "eol" }

T["styles"] = MiniTest.new_set({
  parametrize = {
    { "background", { hl_group = "OCP_ff0000" }, { fg = 0x000000, bg = 0xff0000 } },
    { "foreground", { hl_group = "OCP_ff0000" }, { fg = 0xff0000 } },
    { "virtual_left", inline, { fg = 0xff0000 } },
    { "virtual_eol", eol, { fg = 0xff0000 } },
    { "foreground+virtual_left", vim.tbl_extend("force", inline, { hl_group = "OCP_ff0000" }), { fg = 0xff0000 } },
    { "foreground+virtual_eol", vim.tbl_extend("force", eol, { hl_group = "OCP_ff0000" }), { fg = 0xff0000 } },
  },
})

T["styles"]["set the extmark and the group"] = function(style, mark, group)
  child.configure({ highlight = { style = style, bold = true, italic = true } })
  local buf = H.detached(child, { "#ff0000" })
  H.rehl(child, buf)

  local expected_mark, expected_group = shape(mark, group)
  expect.equality(child.lua_get("h.mark_detail(...)", { buf }), expected_mark)
  expect.equality(child.lua_get("h.hl_def(...)", { "OCP_ff0000" }), expected_group)
end

T["tints only colors close to the background"] = function()
  child.configure({ highlight = { style = "foreground" } })
  child.api.nvim_set_hl(0, "Normal", { bg = 0x000000 })
  child.lua("require('oklch-color-picker.highlight').update_emphasis_values()")

  local buf = H.detached(child, { "#050505 #ff0000" })
  H.rehl(child, buf)

  expect.equality(child.lua_get("h.hl_def(...)", { "OCP_050505" }).bg, 0x323232)
  expect.equality(child.lua_get("h.hl_def(...)", { "OCP_ff0000" }).bg, false)
end

T["an invalid style disables highlighting"] = function()
  child.setup({ highlight = { style = "nope" } }, true)
  expect.equality(child.lua_get("h.wait_notification(...)", { "Invalid config.highlight.style" }) ~= vim.NIL, true)
  expect.equality(child.lua_get("require('oklch-color-picker.highlight').parse == nil"), true)
end

return T
