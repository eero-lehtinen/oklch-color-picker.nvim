local ok, err = xpcall(function()
  local plugin = require("oklch-color-picker")
  plugin.setup({})
  assert(plugin.highlight.parse("#ff0000") == 0xff0000, "Parser returned the wrong color")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "#ff0000" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  assert(plugin.pick_under_cursor(), "Could not start the picker")
  vim.fn.writefile({ "ready" }, "/tmp/oklch-ready")
end, debug.traceback)

if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
