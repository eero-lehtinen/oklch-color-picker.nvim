local H = require("helpers")
local expect = MiniTest.expect

local child = H.new_child()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.setup({ highlight = { enabled = true } })
    end,
    post_once = child.stop,
  },
})

---@param row integer
---@param start_col integer
---@param end_col integer
---@return table
local function blue(row, start_col, end_col)
  return {
    range = { start = { line = row, character = start_col }, ["end"] = { line = row, character = end_col } },
    color = { red = 0, green = 0, blue = 1, alpha = 1 },
  }
end

T["marks LSP colors and drops overlapping regex marks"] = function()
  local buf = H.live(child, { "color: #ff0000 and #00ff00" })
  H.expect_marks_eventually(child, buf, { "0:7-14:OCP_ff0000", "0:19-26:OCP_00ff00" })

  child.lua("h.start_lsp(...)", { buf, "tailwindcss", { blue(0, 7, 14) } })
  child.lua("h.request_lsp(...)", { buf })

  H.expect_marks_eventually(child, buf, { "0:7-14:OCP_0000ff" }, "tailwindcss")
  H.expect_marks_eventually(child, buf, { "0:19-26:OCP_00ff00" })
  H.expect_cache_consistent(child, buf)
end

T["replaces the marks of a previous response"] = function()
  local buf = H.live(child, { "color: #ff0000 and #00ff00" })
  child.lua("h.start_lsp(...)", { buf, "tailwindcss", { blue(0, 7, 14) } })
  child.lua("h.request_lsp(...)", { buf })
  H.expect_marks_eventually(child, buf, { "0:7-14:OCP_0000ff" }, "tailwindcss")

  child.lua("h.set_lsp_colors(...)", { "tailwindcss", { blue(0, 19, 26) } })
  child.lua("h.request_lsp(...)", { buf })
  H.expect_marks_eventually(child, buf, { "0:19-26:OCP_0000ff" }, "tailwindcss")
  H.expect_cache_consistent(child, buf)
end

T["does not request colors from a disabled client"] = function()
  local buf = H.live(child, { "color: #ff0000" })
  child.lua("h.start_lsp(...)", { buf, "some_other_lsp", { blue(0, 7, 14) } })
  expect.equality(child.lua_get("h.request_lsp_sync(...)", { buf }), true)
  expect.equality(child.lua_get("h.lsp.some_other_lsp.requests"), 0)
  H.expect_marks(child, buf, { "0:7-14:OCP_ff0000" })
end

T["converts utf-16 offsets"] = function()
  local buf = H.live(child, { "→ #ff0000" })
  child.lua("h.start_lsp(...)", { buf, "tailwindcss", { blue(0, 2, 9) } })
  child.lua("h.request_lsp(...)", { buf })
  H.expect_marks_eventually(child, buf, { "0:4-11:OCP_0000ff" }, "tailwindcss")
  H.expect_cache_consistent(child, buf)
end

T["recovers from an error response"] = function()
  local buf = H.live(child, { "color: #ff0000 and #00ff00" })
  child.lua("h.start_lsp(...)", { buf, "tailwindcss", { blue(0, 7, 14) } })
  child.lua("h.request_lsp(...)", { buf })
  H.expect_marks_eventually(child, buf, { "0:7-14:OCP_0000ff" }, "tailwindcss")

  local requests = child.lua_get("h.lsp.tailwindcss.requests")
  child.lua("h.set_lsp_error(...)", { "tailwindcss", { code = -32603, message = "boom" } })
  child.lua("h.request_lsp(...)", { buf })
  expect.equality(child.lua_get("h.wait_lsp_requests(...)", { "tailwindcss", requests + 1 }), requests + 1)
  expect.equality(child.lua_get("h.wait_lsp_idle(...)", { buf }), true)
  H.expect_marks(child, buf, { "0:7-14:OCP_0000ff" }, "tailwindcss")

  child.lua("h.set_lsp_error(...)", { "tailwindcss" })
  child.lua("h.set_lsp_colors(...)", { "tailwindcss", { blue(0, 19, 26) } })
  child.lua("h.request_lsp(...)", { buf })
  H.expect_marks_eventually(child, buf, { "0:19-26:OCP_0000ff" }, "tailwindcss")
  H.expect_cache_consistent(child, buf)
end

return T
