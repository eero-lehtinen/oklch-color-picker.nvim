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

T["parses every supported format"] = function()
  local buf = H.detached(child, {
    "#f00",
    "#ff0000",
    "#ff0000ff",
    "0xFF8800",
    "rgb(255, 0, 0)",
    "hsl(120, 100%, 50%)",
    "oklch(70% 0.1 200)",
    "bg-red-500",
  })
  H.rehl(child, buf)
  H.expect_marks(child, buf, {
    "0:0-4:OCP_ff0000",
    "1:0-7:OCP_ff0000",
    "2:0-9:OCP_ff0000",
    "3:0-8:OCP_ff8800",
    "4:0-14:OCP_ff0000",
    "5:0-19:OCP_00ff00",
    "6:0-18:OCP_40b1b7",
    "7:0-10:OCP_fb2c36",
  })
end

T["ignores unparseable matches"] = function()
  local buf = H.detached(child, { "#ggg", "bg-nope-500" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, {})
end

T["highlights every default pattern on one line"] = function()
  local buf = H.detached(
    child,
    { "#f00 0xFF8800 rgb(255, 0, 0) hsl(120, 100%, 50%) oklch(70% 0.1 200) bg-red-500 vec3(0.5, 0.5, 0.5)" }
  )
  H.rehl(child, buf)
  H.expect_marks(child, buf, {
    "0:0-4:OCP_ff0000",
    "0:5-13:OCP_ff8800",
    "0:14-28:OCP_ff0000",
    "0:29-48:OCP_00ff00",
    "0:49-67:OCP_40b1b7",
    "0:68-78:OCP_fb2c36",
    "0:83-98:OCP_808080",
  })
end

T["lets a higher priority pattern win over a nested match"] = function()
  local buf = H.detached(child, { "rgb(255, 0, 0)" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-14:OCP_ff0000" })
  -- The outer mark is reused on the second pass, so the inner match must stay
  -- blocked by the reused mark rather than by the freshly created one.
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-14:OCP_ff0000" })
  expect.equality(H.ids(child, buf), { 1 })
end

T["config"] = MiniTest.new_set()

T["config"]["applies format and ft of a custom pattern"] = function()
  child.configure([[{
    patterns = {
      numbers_in_brackets = false,
      glsl_vec = { priority = 5, format = "raw_rgb_float", ft = { "glsl" }, "vec3%(()[%d.,%s]+()%)" },
    },
  }]])
  local glsl = H.detached(child, { "vec3(1,0.5,0)" }, "glsl")
  H.rehl(child, glsl)
  H.expect_marks(child, glsl, { "0:0-13:OCP_ff8000" })

  local lua = H.detached(child, { "vec3(1,0.5,0)" }, "lua")
  H.rehl(child, lua)
  H.expect_marks(child, lua, {})
end

T["config"]["disables a default pattern set to false"] = function()
  child.configure({ patterns = { hex = false } })
  local buf = H.detached(child, { "#ff0000 bg-red-500" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:8-18:OCP_fb2c36" })
end

T["config"]["reports an invalid pattern and keeps the rest of its list"] = function()
  child.configure([[{
    patterns = {
      hex = false,
      custom = { "()#%x%x%x+", "()#%x%x%x+%f[%W]()" },
    },
  }]])
  local msg = child.lua_get("h.wait_notification(...)", { "custom[1]" })
  expect.equality(type(msg), "string")
  expect.equality(msg:find("Contains only one empty group.", 1, true) ~= nil, true)

  local buf = H.detached(child, { "#ff0000" })
  H.rehl(child, buf)
  H.expect_marks(child, buf, { "0:0-7:OCP_ff0000" })
end

return T
